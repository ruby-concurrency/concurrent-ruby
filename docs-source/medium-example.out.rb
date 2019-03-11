require 'concurrent-edge'                # => true

# This little bit more complicated commented example aims to
# demonstrate some of the capabilities of concurrent-ruby new abstractions.

# It is a concurrent processing pipeline which on one side has several web crawlers.
# They are searching the web for data and filling buffer.
# On the other side there are data processors which are pop the data from buffer.
# They are processing the data and storing results into a DB
# which has limited concurrency level.
# Some of the parts like Web and DB are just stubs.
# Each part logs and increments counters to keep some stats about the pipeline.
# There is also a periodical readout of the stats into log scheduled.

# Schema of the pipeline:

# web-crawlers -> buffer -> data-processing -> DB
#            \____________________________\_____\___> logging

# TODO (pitr-ch 10-Mar-2019): replace with a better more realistic example using
# * actors for limited concurrency with state - local DB connection
# * throttled futures for REST API - limiting server load

# The central logger is defined first.
# It has state like the logger instance, therefore the actor is used.
# It is better to exactly define the communication protocol of the logging actor.
# It will only understand these messages.
Log      = Concurrent::ImmutableStruct.new :severity, :message
# => Log
SetLevel = Concurrent::ImmutableStruct.new :level
# => SetLevel

require 'logger'                         # => false
require 'stringio'                       # => false

# Including actor constants so this scope understands ANY etc.
include Concurrent::ErlangActor::EnvironmentConstants
# => Object
# The logger does not need a dedicated thread, let's use a pool.
LOGGING = Concurrent::ErlangActor.spawn Logger::FATAL,
                                        type: :on_pool,
                                        name: 'logger' do |level|
  # a Logger instance with nicer formatting is created
  @logger           = Logger.new($captured_out)
  @logger.level     = level
  @logger.formatter = lambda do |severity, datetime, progname, msg|
    formatted_message = case msg
                        when String
                          msg
                        when Exception
                          format "%s (%s)\n%s",
                                 msg.message, msg.class, (msg.backtrace || []).join("\n")
                        else
                          msg.inspect
                        end
    format "[%s] %5s -- %s: %s\n",
           datetime.strftime('%Y-%m-%d %H:%M:%S.%L'),
           severity,
           progname,
           formatted_message
  end

  # definition of the logging actor behaviour
  receive(
      # log messages
      on(Log) { |message| @logger.log message.severity, message.message },
      # change level
      on(SetLevel) { |message| @logger.level = message.level },
      # It is a good practice to read and log bad messages,
      # otherwise they would accumulate in the inbox.
      on(ANY) { |message| @logger.error bad_message: message },
      # The logger has static behaviour, therefore keep can be used, and the actor
      # will behave the same with each message received as defined below.
      keep: true)
end
# => #<Concurrent::ErlangActor::Pid:0x000002 logger running>

# testing the logger works as expected
LOGGING.tell Log[Logger::FATAL, :tornado]
# => #<Concurrent::ErlangActor::Pid:0x000002 logger running>
LOGGING.tell Log[Logger::INFO, :wind]
# => #<Concurrent::ErlangActor::Pid:0x000002 logger running>
LOGGING.tell SetLevel[Logger::DEBUG]
# => #<Concurrent::ErlangActor::Pid:0x000002 logger running>
LOGGING.tell Log[Logger::INFO, :breeze]
# => #<Concurrent::ErlangActor::Pid:0x000002 logger running>

sleep 0.05 # the logging is asynchronous, we need to wait a bit until it's written
get_captured_output
# => "[2019-03-11 10:15:11.819] FATAL -- : :tornado\n" +
#    "[2019-03-11 10:15:11.820]  INFO -- : :breeze\n"

# the logging could be wrapped in a method
def log(severity, message)
  LOGGING.tell Log[severity, message]
  true
end                                      # => :log

include Logger::Severity                 # => Object
log INFO, 'alive'                        # => true
sleep 0.05                               # => 0
get_captured_output
# => "[2019-03-11 10:15:11.871]  INFO -- : alive\n"


# The stub which will represent the web
module Web
  @counter = Concurrent::AtomicFixnum.new

  def self.search
    sleep 0.01
    @counter.increment.to_s(16)
  end
end 

# The cancellation which will be used to cancel the whole processing pipeline.
@cancellation, origin = Concurrent::Cancellation.new
# => #<Concurrent::Cancellation:0x000003 pending>

# Buffer for work
buffer_capacity   = 10                   # => 10
@buffer           = Concurrent::Promises::Channel.new buffer_capacity
# => #<Concurrent::Promises::Channel:0x000004 capacity taken 0 of 10>
web_crawler_count = 4                    # => 4

# Track the number of data provided by each crawler
crawler_data_counter = Array.new(web_crawler_count) do |i|
  # this is accessed by multiple threads so it should be a tread-safe counter
  Concurrent::AtomicFixnum.new
end 
# the array is frozen which makes it immutable,
# therefore safe to use when concurrently accessed.
# Otherwise if it was being modified it wound has to be Concurrent::Array to make it safe.
crawler_data_counter.freeze
# => [#<Concurrent::AtomicFixnum:0x000005 value:0>,
#     #<Concurrent::AtomicFixnum:0x000006 value:0>,
#     #<Concurrent::AtomicFixnum:0x000007 value:0>,
#     #<Concurrent::AtomicFixnum:0x000008 value:0>]

# The web crawlers are defined directly with threads to start the example simply.
# They search the web and immediately as they find something they push
# the data into the buffer.
# The push will block if the buffer is full,
# regulating how fast is the work being found.
# This is called backpressure.
crawlers = Array.new web_crawler_count do |i|
  Thread.new do
    while true
      # crawl the web until cancelled
      break if @cancellation.canceled?
      # will block and slow down the crawler if the buffer is full
      data = Web.search
      until @buffer.push data, 0.1
        # It is a good practice to use timeouts on all blocking operations
        # If the pipeline is cancelled and the data-processors finish
        # before taking data from buffer a crawler could get stack on this push.
        break if @cancellation.canceled?
      end
      # it pushed data, increment its counter
      crawler_data_counter[i].increment
      log DEBUG, "crawler #{i} found #{data}"
    end
  end
end.freeze
# => [#<Thread:0x000009@medium-example.in.rb:130 sleep>,
#     #<Thread:0x00000a@medium-example.in.rb:130 sleep>,
#     #<Thread:0x00000b@medium-example.in.rb:130 sleep>,
#     #<Thread:0x00000c@medium-example.in.rb:130 run>]

# So far only the crawlers looking for data are defined
# pushing data into the buffer.
# The data processing definition follows.
# Threads are not used again directly but rather the data processing
# is defined using Futures.
# Even though that makes the definition more complicated
# it has a big advantage that data processors will not require a Thread each
# but they will share and run on a Thread pool.
# That removes an important limitation of the total number of threads process can have,
# which can be an issue in larger systems.
# This example would be fine with using the Threads
# however it would not demonstrate the more advanced usage then.

# The data processing stores results in a DB,
# therefore the stub definition of a database precedes the data processing.
module DB
  @data = Concurrent::Map.new

  # increment a counter for char
  def self.add(char, count)
    @data.compute char do |old|
      (old || 0) + count
    end
    true
  end

  # return the stored data as Hash
  def self.data
    @data.each_pair.reduce({}) { |h, (k, v)| h.update k => v }
  end
end                                      # => :data

# Lets assume that instead having this DB
# we have limited number of connections
# and therefore there is a limit on
# how many threads can communicate with the DB at the same time.
# The throttle is created to limit the number of concurrent access to DB.
@db_throttle = Concurrent::Throttle.new 4
# => #<Concurrent::Throttle:0x00000d capacity available 4 of 4>

# The data processing definition follows
data_processing_count = 20 # this could actually be thousands if required

# track the number of data received by data processors
@data_processing_counters = Array.new data_processing_count do
  Concurrent::AtomicFixnum.new
end.freeze
# => [#<Concurrent::AtomicFixnum:0x00000e value:0>,
#     #<Concurrent::AtomicFixnum:0x00000f value:0>,
#     #<Concurrent::AtomicFixnum:0x000010 value:0>,
#     #<Concurrent::AtomicFixnum:0x000011 value:0>,
#     #<Concurrent::AtomicFixnum:0x000012 value:0>,
#     #<Concurrent::AtomicFixnum:0x000013 value:0>,
#     #<Concurrent::AtomicFixnum:0x000014 value:0>,
#     #<Concurrent::AtomicFixnum:0x000015 value:0>,
#     #<Concurrent::AtomicFixnum:0x000016 value:0>,
#     #<Concurrent::AtomicFixnum:0x000017 value:0>,
#     #<Concurrent::AtomicFixnum:0x000018 value:0>,
#     #<Concurrent::AtomicFixnum:0x000019 value:0>,
#     #<Concurrent::AtomicFixnum:0x00001a value:0>,
#     #<Concurrent::AtomicFixnum:0x00001b value:0>,
#     #<Concurrent::AtomicFixnum:0x00001c value:0>,
#     #<Concurrent::AtomicFixnum:0x00001d value:0>,
#     #<Concurrent::AtomicFixnum:0x00001e value:0>,
#     #<Concurrent::AtomicFixnum:0x00001f value:0>,
#     #<Concurrent::AtomicFixnum:0x000020 value:0>,
#     #<Concurrent::AtomicFixnum:0x000021 value:0>]

def data_processing(i)
  # pop_op returns a future which is fulfilled with a message from buffer
  # when a message is valuable.
  @buffer.pop_op.then_on(:fast) do |data|
    # then we process the message on :fast pool since this has no blocking
    log DEBUG, "data-processor #{i} got #{data}"
    @data_processing_counters[i].increment
    sleep 0.1 # simulate it actually doing something which take some time
    # find the most frequent char
    data.chars.
        group_by { |v| v }.
        map { |ch, arr| [ch, arr.size] }.
        max_by { |ch, size| size }
  end.then_on(@db_throttle.on(:io)) do |char, count|
    # the db access has to be limited therefore the db_throttle is used
    # DBs use io therefore this part is executed on global thread pool wor :io
    DB.add char, count
  end.then_on(:fast) do |_|
    # last section executes back on :fast executor
    # checks if it was cancelled
    # if not then it calls itself recursively
    # which in combination with #run will turn this into infinite data processing
    # (until cancelled)
    # The #run will keep flatting to the inner future as long the value is a future.
    if @cancellation.canceled?
      # return something else then future, #run will stop executing
      :done
    else
      # continue running with a future returned by data_processing
      data_processing i
    end
  end
end 

# create the data processors
data_processors = Array.new data_processing_count do |i|
  data_processing(i).run
end
# => [#<Concurrent::Promises::Future:0x000022 pending>,
#     #<Concurrent::Promises::Future:0x000023 pending>,
#     #<Concurrent::Promises::Future:0x000024 pending>,
#     #<Concurrent::Promises::Future:0x000025 pending>,
#     #<Concurrent::Promises::Future:0x000026 pending>,
#     #<Concurrent::Promises::Future:0x000027 pending>,
#     #<Concurrent::Promises::Future:0x000028 pending>,
#     #<Concurrent::Promises::Future:0x000029 pending>,
#     #<Concurrent::Promises::Future:0x00002a pending>,
#     #<Concurrent::Promises::Future:0x00002b pending>,
#     #<Concurrent::Promises::Future:0x00002c pending>,
#     #<Concurrent::Promises::Future:0x00002d pending>,
#     #<Concurrent::Promises::Future:0x00002e pending>,
#     #<Concurrent::Promises::Future:0x00002f pending>,
#     #<Concurrent::Promises::Future:0x000030 pending>,
#     #<Concurrent::Promises::Future:0x000031 pending>,
#     #<Concurrent::Promises::Future:0x000032 pending>,
#     #<Concurrent::Promises::Future:0x000033 pending>,
#     #<Concurrent::Promises::Future:0x000034 pending>,
#     #<Concurrent::Promises::Future:0x000035 pending>]

# Some statics are collected in crawler_data_counter
# and @data_processing_counters.
# Schedule a periodical readout to a log.
def readout(crawler_data_counter)
  # schedule readout in 0.4 sec or on cancellation
  (@cancellation.origin | Concurrent::Promises.schedule(0.4)).then do
    log INFO,
        "\ncrawlers found: #{crawler_data_counter.map(&:value).join(', ')}\n" +
            "data processors consumed: #{@data_processing_counters.map(&:value).join(', ')}"
  end.then do
    # reschedule if not cancelled
    readout crawler_data_counter unless @cancellation.canceled?
  end
end                                      # => :readout

# start the periodical readouts
readouts = readout(crawler_data_counter).run
# => #<Concurrent::Promises::Future:0x000036 pending>

sleep 2 # let the whole processing pipeline work
# cancel everything
origin.resolve
# => #<Concurrent::Promises::ResolvableEvent:0x000037 resolved>

# wait for everything to stop
crawlers.each(&:join)
# => [#<Thread:0x000009@medium-example.in.rb:130 dead>,
#     #<Thread:0x00000a@medium-example.in.rb:130 dead>,
#     #<Thread:0x00000b@medium-example.in.rb:130 dead>,
#     #<Thread:0x00000c@medium-example.in.rb:130 dead>]
data_processors.each(&:wait!)[0..10]
# => [#<Concurrent::Promises::Future:0x000022 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000023 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000024 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000025 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000026 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000027 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000028 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x000029 fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x00002a fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x00002b fulfilled with :done>,
#     #<Concurrent::Promises::Future:0x00002c fulfilled with :done>]
readouts.wait!
# => #<Concurrent::Promises::Future:0x000036 fulfilled with nil>

# terminate the logger
Concurrent::ErlangActor.terminate LOGGING, :cancelled
# => true
LOGGING.terminated.wait
# => #<Concurrent::Promises::Future:0x000038 rejected with :cancelled>

# inspect collected char frequencies
DB.data
# => {"1"=>18,
#     "2"=>18,
#     "3"=>18,
#     "4"=>18,
#     "6"=>18,
#     "5"=>18,
#     "7"=>18,
#     "8"=>18,
#     "9"=>18,
#     "b"=>1,
#     "c"=>1,
#     "a"=>7,
#     "d"=>1,
#     "e"=>1,
#     "f"=>1}

# see the logger output
get_captured_output
# => "[2019-03-11 10:15:11.939] DEBUG -- : crawler 2 found 1\n" +
#    "[2019-03-11 10:15:11.941] DEBUG -- : crawler 1 found 2\n" +
#    "[2019-03-11 10:15:11.942] DEBUG -- : data-processor 0 got 1\n" +
#    "[2019-03-11 10:15:11.943] DEBUG -- : data-processor 1 got 2\n" +
#    "[2019-03-11 10:15:11.944] DEBUG -- : crawler 0 found 3\n" +
#    "[2019-03-11 10:15:11.944] DEBUG -- : data-processor 2 got 3\n" +
#    "[2019-03-11 10:15:11.945] DEBUG -- : crawler 3 found 4\n" +
#    "[2019-03-11 10:15:11.946] DEBUG -- : data-processor 3 got 4\n" +
#    "[2019-03-11 10:15:11.951] DEBUG -- : crawler 2 found 5\n" +
#    "[2019-03-11 10:15:11.952] DEBUG -- : crawler 1 found 6\n" +
#    "[2019-03-11 10:15:11.953] DEBUG -- : data-processor 4 got 5\n" +
#    "[2019-03-11 10:15:11.954] DEBUG -- : data-processor 5 got 6\n" +
#    "[2019-03-11 10:15:11.955] DEBUG -- : crawler 0 found 7\n" +
#    "[2019-03-11 10:15:11.956] DEBUG -- : data-processor 6 got 7\n" +
#    "[2019-03-11 10:15:11.956] DEBUG -- : crawler 3 found 8\n" +
#    "[2019-03-11 10:15:11.957] DEBUG -- : data-processor 7 got 8\n" +
#    "[2019-03-11 10:15:11.962] DEBUG -- : crawler 2 found 9\n" +
#    "[2019-03-11 10:15:11.964] DEBUG -- : crawler 1 found a\n" +
#    "[2019-03-11 10:15:11.964] DEBUG -- : crawler 0 found b\n" +
#    "[2019-03-11 10:15:11.965] DEBUG -- : crawler 3 found c\n" +
#    "[2019-03-11 10:15:11.973] DEBUG -- : crawler 2 found d\n" +
#    "[2019-03-11 10:15:11.974] DEBUG -- : crawler 1 found e\n" +
#    "[2019-03-11 10:15:11.975] DEBUG -- : crawler 3 found f\n" +
#    "[2019-03-11 10:15:11.977] DEBUG -- : crawler 0 found 10\n" +
#    "[2019-03-11 10:15:11.986] DEBUG -- : crawler 2 found 11\n" +
#    "[2019-03-11 10:15:11.987] DEBUG -- : crawler 1 found 12\n" +
#    "[2019-03-11 10:15:11.988] DEBUG -- : crawler 3 found 13\n" +
#    "[2019-03-11 10:15:11.989] DEBUG -- : crawler 0 found 14\n" +
#    "[2019-03-11 10:15:11.997] DEBUG -- : crawler 2 found 15\n" +
#    "[2019-03-11 10:15:11.998] DEBUG -- : crawler 1 found 16\n" +
#    "[2019-03-11 10:15:11.999] DEBUG -- : crawler 3 found 17\n" +
#    "[2019-03-11 10:15:12.000] DEBUG -- : crawler 0 found 18\n" +
#    "[2019-03-11 10:15:12.010] DEBUG -- : crawler 2 found 19\n" +
#    "[2019-03-11 10:15:12.011] DEBUG -- : crawler 1 found 1a\n" +
#    "[2019-03-11 10:15:12.012] DEBUG -- : crawler 3 found 1b\n" +
#    "[2019-03-11 10:15:12.014] DEBUG -- : crawler 0 found 1c\n" +
#    "[2019-03-11 10:15:12.022] DEBUG -- : crawler 2 found 1d\n" +
#    "[2019-03-11 10:15:12.023] DEBUG -- : crawler 1 found 1e\n" +
#    "[2019-03-11 10:15:12.044] DEBUG -- : data-processor 8 got 9\n" +
#    "[2019-03-11 10:15:12.046] DEBUG -- : data-processor 9 got a\n" +
#    "[2019-03-11 10:15:12.047] DEBUG -- : data-processor 10 got b\n" +
#    "[2019-03-11 10:15:12.048] DEBUG -- : data-processor 11 got c\n" +
#    "[2019-03-11 10:15:12.056] DEBUG -- : data-processor 12 got d\n" +
#    "[2019-03-11 10:15:12.057] DEBUG -- : data-processor 13 got e\n" +
#    "[2019-03-11 10:15:12.058] DEBUG -- : data-processor 14 got f\n" +
#    "[2019-03-11 10:15:12.061] DEBUG -- : data-processor 15 got 10\n" +
#    "[2019-03-11 10:15:12.149] DEBUG -- : data-processor 16 got 11\n" +
#    "[2019-03-11 10:15:12.151] DEBUG -- : data-processor 17 got 12\n" +
#    "[2019-03-11 10:15:12.152] DEBUG -- : data-processor 18 got 13\n" +
#    "[2019-03-11 10:15:12.153] DEBUG -- : data-processor 19 got 14\n" +
#    "[2019-03-11 10:15:12.163] DEBUG -- : data-processor 0 got 15\n" +
#    "[2019-03-11 10:15:12.164] DEBUG -- : crawler 3 found 1f\n" +
#    "[2019-03-11 10:15:12.165] DEBUG -- : crawler 0 found 20\n" +
#    "[2019-03-11 10:15:12.166] DEBUG -- : crawler 1 found 22\n" +
#    "[2019-03-11 10:15:12.167] DEBUG -- : crawler 2 found 21\n" +
#    "[2019-03-11 10:15:12.167] DEBUG -- : data-processor 1 got 16\n" +
#    "[2019-03-11 10:15:12.168] DEBUG -- : data-processor 2 got 17\n" +
#    "[2019-03-11 10:15:12.169] DEBUG -- : data-processor 3 got 18\n" +
#    "[2019-03-11 10:15:12.174] DEBUG -- : crawler 3 found 23\n" +
#    "[2019-03-11 10:15:12.174] DEBUG -- : crawler 0 found 24\n" +
#    "[2019-03-11 10:15:12.175] DEBUG -- : crawler 2 found 25\n" +
#    "[2019-03-11 10:15:12.176] DEBUG -- : crawler 1 found 26\n" +
#    "[2019-03-11 10:15:12.185] DEBUG -- : crawler 3 found 27\n" +
#    "[2019-03-11 10:15:12.185] DEBUG -- : crawler 1 found 28\n" +
#    "[2019-03-11 10:15:12.186] DEBUG -- : crawler 2 found 29\n" +
#    "[2019-03-11 10:15:12.187] DEBUG -- : crawler 0 found 2a\n" +
#    "[2019-03-11 10:15:12.254] DEBUG -- : data-processor 5 got 19\n" +
#    "[2019-03-11 10:15:12.255] DEBUG -- : data-processor 4 got 1a\n" +
#    "[2019-03-11 10:15:12.256] DEBUG -- : data-processor 6 got 1b\n" +
#    "[2019-03-11 10:15:12.258] DEBUG -- : data-processor 7 got 1c\n" +
#    "[2019-03-11 10:15:12.267] DEBUG -- : data-processor 8 got 1d\n" +
#    "[2019-03-11 10:15:12.268] DEBUG -- : data-processor 10 got 1e\n" +
#    "[2019-03-11 10:15:12.269] DEBUG -- : data-processor 11 got 1f\n" +
#    "[2019-03-11 10:15:12.269] DEBUG -- : data-processor 9 got 20\n" +
#    "[2019-03-11 10:15:12.336]  INFO -- : \n" +
#    "crawlers found: 10, 11, 11, 10\n" +
#    "data processors consumed: 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1\n" +
#    "[2019-03-11 10:15:12.361] DEBUG -- : data-processor 12 got 22\n" +
#    "[2019-03-11 10:15:12.362] DEBUG -- : data-processor 13 got 21\n" +
#    "[2019-03-11 10:15:12.363] DEBUG -- : data-processor 14 got 23\n" +
#    "[2019-03-11 10:15:12.363] DEBUG -- : data-processor 15 got 24\n" +
#    "[2019-03-11 10:15:12.364] DEBUG -- : crawler 3 found 2b\n" +
#    "[2019-03-11 10:15:12.365] DEBUG -- : crawler 1 found 2c\n" +
#    "[2019-03-11 10:15:12.365] DEBUG -- : crawler 0 found 2e\n" +
#    "[2019-03-11 10:15:12.366] DEBUG -- : crawler 2 found 2d\n" +
#    "[2019-03-11 10:15:12.371] DEBUG -- : data-processor 16 got 25\n" +
#    "[2019-03-11 10:15:12.371] DEBUG -- : data-processor 17 got 26\n" +
#    "[2019-03-11 10:15:12.372] DEBUG -- : data-processor 18 got 27\n" +
#    "[2019-03-11 10:15:12.373] DEBUG -- : data-processor 19 got 28\n" +
#    "[2019-03-11 10:15:12.374] DEBUG -- : crawler 3 found 2f\n" +
#    "[2019-03-11 10:15:12.374] DEBUG -- : crawler 2 found 30\n" +
#    "[2019-03-11 10:15:12.375] DEBUG -- : crawler 0 found 31\n" +
#    "[2019-03-11 10:15:12.376] DEBUG -- : crawler 1 found 32\n" +
#    "[2019-03-11 10:15:12.383] DEBUG -- : crawler 3 found 33\n" +
#    "[2019-03-11 10:15:12.384] DEBUG -- : crawler 2 found 34\n" +
#    "[2019-03-11 10:15:12.385] DEBUG -- : crawler 0 found 35\n" +
#    "[2019-03-11 10:15:12.385] DEBUG -- : crawler 1 found 36\n" +
#    "[2019-03-11 10:15:12.465] DEBUG -- : data-processor 1 got 29\n" +
#    "[2019-03-11 10:15:12.465] DEBUG -- : data-processor 2 got 2a\n" +
#    "[2019-03-11 10:15:12.467] DEBUG -- : data-processor 3 got 2b\n" +
#    "[2019-03-11 10:15:12.468] DEBUG -- : data-processor 0 got 2c\n" +
#    "[2019-03-11 10:15:12.479] DEBUG -- : data-processor 4 got 2e\n" +
#    "[2019-03-11 10:15:12.481] DEBUG -- : data-processor 6 got 2d\n" +
#    "[2019-03-11 10:15:12.482] DEBUG -- : crawler 3 found 37\n" +
#    "[2019-03-11 10:15:12.483] DEBUG -- : crawler 2 found 38\n" +
#    "[2019-03-11 10:15:12.484] DEBUG -- : crawler 0 found 39\n" +
#    "[2019-03-11 10:15:12.484] DEBUG -- : data-processor 7 got 2f\n" +
#    "[2019-03-11 10:15:12.485] DEBUG -- : data-processor 5 got 30\n" +
#    "[2019-03-11 10:15:12.486] DEBUG -- : crawler 1 found 3a\n" +
#    "[2019-03-11 10:15:12.491] DEBUG -- : crawler 3 found 3b\n" +
#    "[2019-03-11 10:15:12.492] DEBUG -- : crawler 2 found 3c\n" +
#    "[2019-03-11 10:15:12.493] DEBUG -- : crawler 0 found 3d\n" +
#    "[2019-03-11 10:15:12.494] DEBUG -- : crawler 1 found 3e\n" +
#    "[2019-03-11 10:15:12.503] DEBUG -- : crawler 2 found 3f\n" +
#    "[2019-03-11 10:15:12.504] DEBUG -- : crawler 3 found 40\n" +
#    "[2019-03-11 10:15:12.506] DEBUG -- : crawler 0 found 41\n" +
#    "[2019-03-11 10:15:12.507] DEBUG -- : crawler 1 found 42\n" +
#    "[2019-03-11 10:15:12.568] DEBUG -- : data-processor 8 got 31\n" +
#    "[2019-03-11 10:15:12.570] DEBUG -- : data-processor 11 got 32\n" +
#    "[2019-03-11 10:15:12.571] DEBUG -- : data-processor 9 got 33\n" +
#    "[2019-03-11 10:15:12.572] DEBUG -- : data-processor 10 got 34\n" +
#    "[2019-03-11 10:15:12.583] DEBUG -- : data-processor 13 got 35\n" +
#    "[2019-03-11 10:15:12.585] DEBUG -- : data-processor 15 got 36\n" +
#    "[2019-03-11 10:15:12.586] DEBUG -- : data-processor 14 got 37\n" +
#    "[2019-03-11 10:15:12.587] DEBUG -- : data-processor 12 got 38\n" +
#    "[2019-03-11 10:15:12.675] DEBUG -- : data-processor 19 got 39\n" +
#    "[2019-03-11 10:15:12.676] DEBUG -- : crawler 2 found 43\n" +
#    "[2019-03-11 10:15:12.677] DEBUG -- : crawler 0 found 45\n" +
#    "[2019-03-11 10:15:12.678] DEBUG -- : crawler 3 found 44\n" +
#    "[2019-03-11 10:15:12.679] DEBUG -- : data-processor 17 got 3a\n" +
#    "[2019-03-11 10:15:12.679] DEBUG -- : data-processor 16 got 3b\n" +
#    "[2019-03-11 10:15:12.680] DEBUG -- : data-processor 18 got 3c\n" +
#    "[2019-03-11 10:15:12.681] DEBUG -- : crawler 1 found 46\n" +
#    "[2019-03-11 10:15:12.688] DEBUG -- : crawler 0 found 47\n" +
#    "[2019-03-11 10:15:12.690] DEBUG -- : data-processor 2 got 3d\n" +
#    "[2019-03-11 10:15:12.690] DEBUG -- : data-processor 1 got 3e\n" +
#    "[2019-03-11 10:15:12.691] DEBUG -- : crawler 1 found 48\n" +
#    "[2019-03-11 10:15:12.692] DEBUG -- : crawler 3 found 49\n" +
#    "[2019-03-11 10:15:12.693] DEBUG -- : data-processor 0 got 3f\n" +
#    "[2019-03-11 10:15:12.693] DEBUG -- : crawler 2 found 4a\n" +
#    "[2019-03-11 10:15:12.694] DEBUG -- : data-processor 3 got 40\n" +
#    "[2019-03-11 10:15:12.700] DEBUG -- : crawler 0 found 4b\n" +
#    "[2019-03-11 10:15:12.701] DEBUG -- : crawler 1 found 4c\n" +
#    "[2019-03-11 10:15:12.702] DEBUG -- : crawler 3 found 4d\n" +
#    "[2019-03-11 10:15:12.702] DEBUG -- : crawler 2 found 4e\n" +
#    "[2019-03-11 10:15:12.743]  INFO -- : \n" +
#    "crawlers found: 19, 20, 20, 19\n" +
#    "data processors consumed: 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3\n" +
#    "[2019-03-11 10:15:12.780] DEBUG -- : data-processor 4 got 41\n" +
#    "[2019-03-11 10:15:12.782] DEBUG -- : data-processor 7 got 42\n" +
#    "[2019-03-11 10:15:12.783] DEBUG -- : data-processor 5 got 43\n" +
#    "[2019-03-11 10:15:12.783] DEBUG -- : data-processor 6 got 45\n" +
#    "[2019-03-11 10:15:12.793] DEBUG -- : data-processor 11 got 46\n" +
#    "[2019-03-11 10:15:12.794] DEBUG -- : data-processor 9 got 44\n" +
#    "[2019-03-11 10:15:12.795] DEBUG -- : data-processor 10 got 47\n" +
#    "[2019-03-11 10:15:12.796] DEBUG -- : crawler 0 found 4f\n" +
#    "[2019-03-11 10:15:12.797] DEBUG -- : crawler 1 found 50\n" +
#    "[2019-03-11 10:15:12.797] DEBUG -- : crawler 2 found 51\n" +
#    "[2019-03-11 10:15:12.798] DEBUG -- : crawler 3 found 52\n" +
#    "[2019-03-11 10:15:12.799] DEBUG -- : data-processor 8 got 48\n" +
#    "[2019-03-11 10:15:12.806] DEBUG -- : crawler 0 found 53\n" +
#    "[2019-03-11 10:15:12.807] DEBUG -- : crawler 1 found 54\n" +
#    "[2019-03-11 10:15:12.808] DEBUG -- : crawler 3 found 55\n" +
#    "[2019-03-11 10:15:12.808] DEBUG -- : crawler 2 found 56\n" +
#    "[2019-03-11 10:15:12.816] DEBUG -- : crawler 2 found 57\n" +
#    "[2019-03-11 10:15:12.817] DEBUG -- : crawler 1 found 58\n" +
#    "[2019-03-11 10:15:12.818] DEBUG -- : crawler 0 found 59\n" +
#    "[2019-03-11 10:15:12.819] DEBUG -- : crawler 3 found 5a\n" +
#    "[2019-03-11 10:15:12.883] DEBUG -- : data-processor 12 got 49\n" +
#    "[2019-03-11 10:15:12.884] DEBUG -- : data-processor 15 got 4a\n" +
#    "[2019-03-11 10:15:12.885] DEBUG -- : data-processor 14 got 4b\n" +
#    "[2019-03-11 10:15:12.886] DEBUG -- : data-processor 13 got 4c\n" +
#    "[2019-03-11 10:15:12.897] DEBUG -- : data-processor 19 got 4d\n" +
#    "[2019-03-11 10:15:12.898] DEBUG -- : data-processor 18 got 4e\n" +
#    "[2019-03-11 10:15:12.899] DEBUG -- : data-processor 17 got 4f\n" +
#    "[2019-03-11 10:15:12.900] DEBUG -- : data-processor 16 got 50\n" +
#    "[2019-03-11 10:15:12.989] DEBUG -- : data-processor 0 got 51\n" +
#    "[2019-03-11 10:15:12.991] DEBUG -- : data-processor 2 got 52\n" +
#    "[2019-03-11 10:15:12.992] DEBUG -- : crawler 2 found 5b\n" +
#    "[2019-03-11 10:15:12.993] DEBUG -- : crawler 1 found 5c\n" +
#    "[2019-03-11 10:15:12.994] DEBUG -- : crawler 0 found 5e\n" +
#    "[2019-03-11 10:15:12.994] DEBUG -- : crawler 3 found 5d\n" +
#    "[2019-03-11 10:15:12.995] DEBUG -- : data-processor 1 got 53\n" +
#    "[2019-03-11 10:15:12.996] DEBUG -- : data-processor 3 got 54\n" +
#    "[2019-03-11 10:15:13.001] DEBUG -- : data-processor 7 got 55\n" +
#    "[2019-03-11 10:15:13.002] DEBUG -- : data-processor 4 got 56\n" +
#    "[2019-03-11 10:15:13.003] DEBUG -- : crawler 2 found 5f\n" +
#    "[2019-03-11 10:15:13.004] DEBUG -- : crawler 1 found 60\n" +
#    "[2019-03-11 10:15:13.004] DEBUG -- : crawler 0 found 61\n" +
#    "[2019-03-11 10:15:13.005] DEBUG -- : crawler 3 found 62\n" +
#    "[2019-03-11 10:15:13.006] DEBUG -- : data-processor 5 got 57\n" +
#    "[2019-03-11 10:15:13.007] DEBUG -- : data-processor 6 got 58\n" +
#    "[2019-03-11 10:15:13.011] DEBUG -- : crawler 2 found 63\n" +
#    "[2019-03-11 10:15:13.012] DEBUG -- : crawler 1 found 64\n" +
#    "[2019-03-11 10:15:13.013] DEBUG -- : crawler 0 found 65\n" +
#    "[2019-03-11 10:15:13.013] DEBUG -- : crawler 3 found 66\n" +
#    "[2019-03-11 10:15:13.091] DEBUG -- : data-processor 11 got 59\n" +
#    "[2019-03-11 10:15:13.092] DEBUG -- : data-processor 10 got 5a\n" +
#    "[2019-03-11 10:15:13.093] DEBUG -- : data-processor 8 got 5b\n" +
#    "[2019-03-11 10:15:13.094] DEBUG -- : data-processor 9 got 5c\n" +
#    "[2019-03-11 10:15:13.104] DEBUG -- : data-processor 12 got 5e\n" +
#    "[2019-03-11 10:15:13.106] DEBUG -- : crawler 1 found 67\n" +
#    "[2019-03-11 10:15:13.106] DEBUG -- : crawler 2 found 68\n" +
#    "[2019-03-11 10:15:13.107] DEBUG -- : crawler 0 found 69\n" +
#    "[2019-03-11 10:15:13.108] DEBUG -- : crawler 3 found 6a\n" +
#    "[2019-03-11 10:15:13.108] DEBUG -- : data-processor 15 got 5d\n" +
#    "[2019-03-11 10:15:13.109] DEBUG -- : data-processor 13 got 5f\n" +
#    "[2019-03-11 10:15:13.110] DEBUG -- : data-processor 14 got 60\n" +
#    "[2019-03-11 10:15:13.116] DEBUG -- : crawler 1 found 6b\n" +
#    "[2019-03-11 10:15:13.117] DEBUG -- : crawler 2 found 6c\n" +
#    "[2019-03-11 10:15:13.117] DEBUG -- : crawler 0 found 6d\n" +
#    "[2019-03-11 10:15:13.118] DEBUG -- : crawler 3 found 6e\n" +
#    "[2019-03-11 10:15:13.128] DEBUG -- : crawler 1 found 6f\n" +
#    "[2019-03-11 10:15:13.129] DEBUG -- : crawler 2 found 70\n" +
#    "[2019-03-11 10:15:13.130] DEBUG -- : crawler 3 found 71\n" +
#    "[2019-03-11 10:15:13.131] DEBUG -- : crawler 0 found 72\n" +
#    "[2019-03-11 10:15:13.147]  INFO -- : \n" +
#    "crawlers found: 28, 29, 29, 28\n" +
#    "data processors consumed: 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4\n" +
#    "[2019-03-11 10:15:13.195] DEBUG -- : data-processor 19 got 61\n" +
#    "[2019-03-11 10:15:13.196] DEBUG -- : data-processor 16 got 62\n" +
#    "[2019-03-11 10:15:13.197] DEBUG -- : data-processor 18 got 63\n" +
#    "[2019-03-11 10:15:13.198] DEBUG -- : data-processor 17 got 64\n" +
#    "[2019-03-11 10:15:13.207] DEBUG -- : data-processor 0 got 65\n" +
#    "[2019-03-11 10:15:13.208] DEBUG -- : data-processor 1 got 66\n" +
#    "[2019-03-11 10:15:13.211] DEBUG -- : data-processor 2 got 67\n" +
#    "[2019-03-11 10:15:13.212] DEBUG -- : data-processor 3 got 68\n" +
#    "[2019-03-11 10:15:13.302] DEBUG -- : data-processor 7 got 69\n" +
#    "[2019-03-11 10:15:13.303] DEBUG -- : data-processor 4 got 6a\n" +
#    "[2019-03-11 10:15:13.305] DEBUG -- : data-processor 6 got 6b\n" +
#    "[2019-03-11 10:15:13.306] DEBUG -- : crawler 2 found 74\n" +
#    "[2019-03-11 10:15:13.306] DEBUG -- : crawler 1 found 73\n" +
#    "[2019-03-11 10:15:13.307] DEBUG -- : crawler 3 found 75\n" +
#    "[2019-03-11 10:15:13.308] DEBUG -- : data-processor 5 got 6c\n" +
#    "[2019-03-11 10:15:13.309] DEBUG -- : crawler 0 found 76\n" +
#    "[2019-03-11 10:15:13.311] DEBUG -- : data-processor 11 got 6d\n" +
#    "[2019-03-11 10:15:13.312] DEBUG -- : data-processor 9 got 6e\n" +
#    "[2019-03-11 10:15:13.313] DEBUG -- : crawler 1 found 77\n" +
#    "[2019-03-11 10:15:13.314] DEBUG -- : crawler 2 found 78\n" +
#    "[2019-03-11 10:15:13.314] DEBUG -- : crawler 3 found 79\n" +
#    "[2019-03-11 10:15:13.316] DEBUG -- : data-processor 10 got 6f\n" +
#    "[2019-03-11 10:15:13.317] DEBUG -- : crawler 0 found 7a\n" +
#    "[2019-03-11 10:15:13.318] DEBUG -- : data-processor 8 got 70\n" +
#    "[2019-03-11 10:15:13.324] DEBUG -- : crawler 1 found 7b\n" +
#    "[2019-03-11 10:15:13.325] DEBUG -- : crawler 3 found 7c\n" +
#    "[2019-03-11 10:15:13.326] DEBUG -- : crawler 2 found 7d\n" +
#    "[2019-03-11 10:15:13.327] DEBUG -- : crawler 0 found 7e\n" +
#    "[2019-03-11 10:15:13.406] DEBUG -- : data-processor 12 got 71\n" +
#    "[2019-03-11 10:15:13.407] DEBUG -- : data-processor 15 got 72\n" +
#    "[2019-03-11 10:15:13.408] DEBUG -- : data-processor 13 got 74\n" +
#    "[2019-03-11 10:15:13.409] DEBUG -- : data-processor 14 got 73\n" +
#    "[2019-03-11 10:15:13.419] DEBUG -- : data-processor 16 got 76\n" +
#    "[2019-03-11 10:15:13.420] DEBUG -- : data-processor 18 got 75\n" +
#    "[2019-03-11 10:15:13.421] DEBUG -- : crawler 2 found 7f\n" +
#    "[2019-03-11 10:15:13.422] DEBUG -- : crawler 3 found 80\n" +
#    "[2019-03-11 10:15:13.423] DEBUG -- : crawler 1 found 81\n" +
#    "[2019-03-11 10:15:13.424] DEBUG -- : crawler 0 found 82\n" +
#    "[2019-03-11 10:15:13.424] DEBUG -- : data-processor 17 got 77\n" +
#    "[2019-03-11 10:15:13.425] DEBUG -- : data-processor 19 got 78\n" +
#    "[2019-03-11 10:15:13.430] DEBUG -- : crawler 2 found 83\n" +
#    "[2019-03-11 10:15:13.431] DEBUG -- : crawler 3 found 84\n" +
#    "[2019-03-11 10:15:13.431] DEBUG -- : crawler 1 found 85\n" +
#    "[2019-03-11 10:15:13.432] DEBUG -- : crawler 0 found 86\n" +
#    "[2019-03-11 10:15:13.441] DEBUG -- : crawler 2 found 87\n" +
#    "[2019-03-11 10:15:13.442] DEBUG -- : crawler 1 found 88\n" +
#    "[2019-03-11 10:15:13.443] DEBUG -- : crawler 3 found 89\n" +
#    "[2019-03-11 10:15:13.443] DEBUG -- : crawler 0 found 8a\n" +
#    "[2019-03-11 10:15:13.511] DEBUG -- : data-processor 0 got 79\n" +
#    "[2019-03-11 10:15:13.513] DEBUG -- : data-processor 1 got 7a\n" +
#    "[2019-03-11 10:15:13.514] DEBUG -- : data-processor 3 got 7b\n" +
#    "[2019-03-11 10:15:13.515] DEBUG -- : data-processor 2 got 7c\n" +
#    "[2019-03-11 10:15:13.524] DEBUG -- : data-processor 4 got 7d\n" +
#    "[2019-03-11 10:15:13.525] DEBUG -- : data-processor 6 got 7e\n" +
#    "[2019-03-11 10:15:13.526] DEBUG -- : data-processor 7 got 7f\n" +
#    "[2019-03-11 10:15:13.526] DEBUG -- : data-processor 5 got 80\n" +
#    "[2019-03-11 10:15:13.553]  INFO -- : \n" +
#    "crawlers found: 34, 35, 35, 34\n" +
#    "data processors consumed: 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6\n" +
#    "[2019-03-11 10:15:13.615] DEBUG -- : data-processor 11 got 81\n" +
#    "[2019-03-11 10:15:13.617] DEBUG -- : data-processor 9 got 82\n" +
#    "[2019-03-11 10:15:13.618] DEBUG -- : data-processor 8 got 83\n" +
#    "[2019-03-11 10:15:13.618] DEBUG -- : crawler 2 found 8b\n" +
#    "[2019-03-11 10:15:13.619] DEBUG -- : crawler 1 found 8c\n" +
#    "[2019-03-11 10:15:13.620] DEBUG -- : crawler 0 found 8e\n" +
#    "[2019-03-11 10:15:13.620] DEBUG -- : crawler 3 found 8d\n" +
#    "[2019-03-11 10:15:13.621] DEBUG -- : data-processor 10 got 84\n" +
#    "[2019-03-11 10:15:13.628] DEBUG -- : data-processor 13 got 85\n" +
#    "[2019-03-11 10:15:13.629] DEBUG -- : data-processor 12 got 86\n" +
#    "[2019-03-11 10:15:13.629] DEBUG -- : data-processor 15 got 87\n" +
#    "[2019-03-11 10:15:13.630] DEBUG -- : data-processor 14 got 88\n" +
#    "[2019-03-11 10:15:13.631] DEBUG -- : crawler 2 found 8f\n" +
#    "[2019-03-11 10:15:13.631] DEBUG -- : crawler 1 found 90\n" +
#    "[2019-03-11 10:15:13.632] DEBUG -- : crawler 3 found 91\n" +
#    "[2019-03-11 10:15:13.633] DEBUG -- : crawler 0 found 92\n" +
#    "[2019-03-11 10:15:13.640] DEBUG -- : crawler 2 found 93\n" +
#    "[2019-03-11 10:15:13.640] DEBUG -- : crawler 0 found 94\n" +
#    "[2019-03-11 10:15:13.641] DEBUG -- : crawler 3 found 95\n" +
#    "[2019-03-11 10:15:13.642] DEBUG -- : crawler 1 found 96\n" +
#    "[2019-03-11 10:15:13.718] DEBUG -- : data-processor 17 got 89\n" +
#    "[2019-03-11 10:15:13.719] DEBUG -- : data-processor 19 got 8a\n" +
#    "[2019-03-11 10:15:13.720] DEBUG -- : data-processor 16 got 8b\n" +
#    "[2019-03-11 10:15:13.721] DEBUG -- : data-processor 18 got 8c\n" +
#    "[2019-03-11 10:15:13.736] DEBUG -- : data-processor 3 got 8e\n" +
#    "[2019-03-11 10:15:13.737] DEBUG -- : data-processor 2 got 8d\n" +
#    "[2019-03-11 10:15:13.738] DEBUG -- : data-processor 1 got 8f\n" +
#    "[2019-03-11 10:15:13.739] DEBUG -- : crawler 3 found 97\n" +
#    "[2019-03-11 10:15:13.740] DEBUG -- : crawler 0 found 98\n" +
#    "[2019-03-11 10:15:13.741] DEBUG -- : crawler 1 found 99\n" +
#    "[2019-03-11 10:15:13.742] DEBUG -- : crawler 2 found 9a\n" +
#    "[2019-03-11 10:15:13.743] DEBUG -- : data-processor 0 got 90\n" +
#    "[2019-03-11 10:15:13.747] DEBUG -- : crawler 3 found 9b\n" +
#    "[2019-03-11 10:15:13.748] DEBUG -- : crawler 0 found 9c\n" +
#    "[2019-03-11 10:15:13.749] DEBUG -- : crawler 1 found 9d\n" +
#    "[2019-03-11 10:15:13.750] DEBUG -- : crawler 2 found 9e\n" +
#    "[2019-03-11 10:15:13.757] DEBUG -- : crawler 0 found 9f\n" +
#    "[2019-03-11 10:15:13.758] DEBUG -- : crawler 3 found a0\n" +
#    "[2019-03-11 10:15:13.759] DEBUG -- : crawler 1 found a1\n" +
#    "[2019-03-11 10:15:13.760] DEBUG -- : crawler 2 found a2\n" +
#    "[2019-03-11 10:15:13.822] DEBUG -- : data-processor 6 got 91\n" +
#    "[2019-03-11 10:15:13.824] DEBUG -- : data-processor 4 got 92\n" +
#    "[2019-03-11 10:15:13.825] DEBUG -- : data-processor 5 got 93\n" +
#    "[2019-03-11 10:15:13.826] DEBUG -- : data-processor 7 got 94\n" +
#    "[2019-03-11 10:15:13.840] DEBUG -- : data-processor 8 got 95\n" +
#    "[2019-03-11 10:15:13.841] DEBUG -- : data-processor 10 got 96\n" +
#    "[2019-03-11 10:15:13.842] DEBUG -- : data-processor 9 got 97\n" +
#    "[2019-03-11 10:15:13.843] DEBUG -- : data-processor 11 got 98\n" +
#    "[2019-03-11 10:15:13.933] DEBUG -- : data-processor 12 got 99\n" +
#    "[2019-03-11 10:15:13.934] DEBUG -- : crawler 0 found a4\n" +
#    "[2019-03-11 10:15:13.935] DEBUG -- : data-processor 15 got 9a\n" +
#    "[2019-03-11 10:15:13.935] DEBUG -- : data-processor 14 got 9b\n" +
#    "[2019-03-11 10:15:13.936] DEBUG -- : crawler 1 found a6\n" +
#    "[2019-03-11 10:15:13.936] DEBUG -- : crawler 3 found a3\n" +
#    "[2019-03-11 10:15:13.937] DEBUG -- : data-processor 13 got 9c\n" +
#    "[2019-03-11 10:15:13.938] DEBUG -- : crawler 2 found a5\n" +
#    "[2019-03-11 10:15:13.938]  INFO -- : \n" +
#    "crawlers found: 41, 42, 42, 41\n" +
#    "data processors consumed: 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 7, 7\n" +
#    "[2019-03-11 10:15:13.942] DEBUG -- : data-processor 17 got 9d\n" +
#    "[2019-03-11 10:15:13.943] DEBUG -- : data-processor 19 got 9e\n" +
#    "[2019-03-11 10:15:13.944] DEBUG -- : crawler 0 found a7\n" +
#    "[2019-03-11 10:15:13.945] DEBUG -- : data-processor 16 got 9f\n" +
#    "[2019-03-11 10:15:13.946] DEBUG -- : crawler 1 found a8\n" +
#    "[2019-03-11 10:15:13.947] DEBUG -- : data-processor 18 got a0\n" +
#    "[2019-03-11 10:15:14.033] DEBUG -- : data-processor 2 got a1\n" +
#    "[2019-03-11 10:15:14.035] DEBUG -- : data-processor 3 got a2\n" +
#    "[2019-03-11 10:15:14.035] DEBUG -- : data-processor 1 got a3\n" +
#    "[2019-03-11 10:15:14.036] DEBUG -- : data-processor 0 got a4\n" +
#    "[2019-03-11 10:15:14.044] DEBUG -- : data-processor 6 got a5\n"




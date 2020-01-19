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
# => "[2020-01-19 18:53:43.022] FATAL -- : :tornado\n" +
#    "[2020-01-19 18:53:43.023]  INFO -- : :breeze\n"

# the logging could be wrapped in a method
def log(severity, message)
  LOGGING.tell Log[severity, message]
  true
end                                      # => :log

include Logger::Severity                 # => Object
log INFO, 'alive'                        # => true
sleep 0.05                               # => 0
get_captured_output
# => "[2020-01-19 18:53:43.073]  INFO -- : alive\n"


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
# => [#<Thread:0x000009@medium-example.in.rb:130 run>,
#     #<Thread:0x00000a@medium-example.in.rb:130 run>,
#     #<Thread:0x00000b@medium-example.in.rb:130 run>,
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
# => {"2"=>18,
#     "3"=>18,
#     "4"=>18,
#     "1"=>18,
#     "7"=>18,
#     "5"=>18,
#     "8"=>18,
#     "6"=>18,
#     "9"=>18,
#     "a"=>18,
#     "b"=>18,
#     "c"=>18,
#     "d"=>18,
#     "e"=>18,
#     "f"=>6}

# see the logger output
get_captured_output
# => "[2020-01-19 18:53:43.144] DEBUG -- : crawler 0 found 1\n" +
#    "[2020-01-19 18:53:43.145] DEBUG -- : crawler 2 found 2\n" +
#    "[2020-01-19 18:53:43.145] DEBUG -- : crawler 1 found 3\n" +
#    "[2020-01-19 18:53:43.145] DEBUG -- : data-processor 2 got 3\n" +
#    "[2020-01-19 18:53:43.146] DEBUG -- : crawler 3 found 4\n" +
#    "[2020-01-19 18:53:43.146] DEBUG -- : data-processor 3 got 4\n" +
#    "[2020-01-19 18:53:43.146] DEBUG -- : data-processor 0 got 1\n" +
#    "[2020-01-19 18:53:43.147] DEBUG -- : data-processor 1 got 2\n" +
#    "[2020-01-19 18:53:43.156] DEBUG -- : crawler 0 found 5\n" +
#    "[2020-01-19 18:53:43.156] DEBUG -- : crawler 2 found 6\n" +
#    "[2020-01-19 18:53:43.156] DEBUG -- : crawler 1 found 7\n" +
#    "[2020-01-19 18:53:43.157] DEBUG -- : data-processor 6 got 7\n" +
#    "[2020-01-19 18:53:43.157] DEBUG -- : crawler 3 found 8\n" +
#    "[2020-01-19 18:53:43.157] DEBUG -- : data-processor 7 got 8\n" +
#    "[2020-01-19 18:53:43.157] DEBUG -- : data-processor 4 got 5\n" +
#    "[2020-01-19 18:53:43.158] DEBUG -- : data-processor 5 got 6\n" +
#    "[2020-01-19 18:53:43.166] DEBUG -- : crawler 2 found 9\n" +
#    "[2020-01-19 18:53:43.166] DEBUG -- : data-processor 8 got 9\n" +
#    "[2020-01-19 18:53:43.166] DEBUG -- : crawler 0 found a\n" +
#    "[2020-01-19 18:53:43.167] DEBUG -- : data-processor 9 got a\n" +
#    "[2020-01-19 18:53:43.167] DEBUG -- : crawler 3 found b\n" +
#    "[2020-01-19 18:53:43.167] DEBUG -- : data-processor 10 got b\n" +
#    "[2020-01-19 18:53:43.168] DEBUG -- : crawler 1 found c\n" +
#    "[2020-01-19 18:53:43.168] DEBUG -- : data-processor 11 got c\n" +
#    "[2020-01-19 18:53:43.176] DEBUG -- : crawler 2 found d\n" +
#    "[2020-01-19 18:53:43.176] DEBUG -- : crawler 0 found e\n" +
#    "[2020-01-19 18:53:43.177] DEBUG -- : crawler 3 found f\n" +
#    "[2020-01-19 18:53:43.179] DEBUG -- : crawler 1 found 10\n" +
#    "[2020-01-19 18:53:43.188] DEBUG -- : crawler 2 found 11\n" +
#    "[2020-01-19 18:53:43.188] DEBUG -- : crawler 0 found 12\n" +
#    "[2020-01-19 18:53:43.189] DEBUG -- : crawler 3 found 13\n" +
#    "[2020-01-19 18:53:43.189] DEBUG -- : crawler 1 found 14\n" +
#    "[2020-01-19 18:53:43.200] DEBUG -- : crawler 1 found 15\n" +
#    "[2020-01-19 18:53:43.201] DEBUG -- : crawler 2 found 16\n" +
#    "[2020-01-19 18:53:43.201] DEBUG -- : crawler 0 found 17\n" +
#    "[2020-01-19 18:53:43.201] DEBUG -- : crawler 3 found 18\n" +
#    "[2020-01-19 18:53:43.211] DEBUG -- : crawler 1 found 19\n" +
#    "[2020-01-19 18:53:43.212] DEBUG -- : crawler 3 found 1a\n" +
#    "[2020-01-19 18:53:43.212] DEBUG -- : crawler 0 found 1b\n" +
#    "[2020-01-19 18:53:43.212] DEBUG -- : crawler 2 found 1c\n" +
#    "[2020-01-19 18:53:43.222] DEBUG -- : crawler 0 found 1d\n" +
#    "[2020-01-19 18:53:43.223] DEBUG -- : crawler 3 found 1e\n" +
#    "[2020-01-19 18:53:43.245] DEBUG -- : data-processor 12 got d\n" +
#    "[2020-01-19 18:53:43.246] DEBUG -- : data-processor 13 got e\n" +
#    "[2020-01-19 18:53:43.246] DEBUG -- : data-processor 14 got f\n" +
#    "[2020-01-19 18:53:43.248] DEBUG -- : data-processor 15 got 10\n" +
#    "[2020-01-19 18:53:43.256] DEBUG -- : data-processor 16 got 11\n" +
#    "[2020-01-19 18:53:43.257] DEBUG -- : data-processor 17 got 12\n" +
#    "[2020-01-19 18:53:43.257] DEBUG -- : data-processor 18 got 13\n" +
#    "[2020-01-19 18:53:43.257] DEBUG -- : data-processor 19 got 14\n" +
#    "[2020-01-19 18:53:43.267] DEBUG -- : data-processor 1 got 15\n" +
#    "[2020-01-19 18:53:43.268] DEBUG -- : crawler 2 found 1f\n" +
#    "[2020-01-19 18:53:43.268] DEBUG -- : crawler 1 found 20\n" +
#    "[2020-01-19 18:53:43.268] DEBUG -- : crawler 0 found 21\n" +
#    "[2020-01-19 18:53:43.269] DEBUG -- : crawler 3 found 22\n" +
#    "[2020-01-19 18:53:43.269] DEBUG -- : data-processor 2 got 16\n" +
#    "[2020-01-19 18:53:43.269] DEBUG -- : data-processor 3 got 17\n" +
#    "[2020-01-19 18:53:43.270] DEBUG -- : data-processor 0 got 18\n" +
#    "[2020-01-19 18:53:43.277] DEBUG -- : crawler 3 found 23\n" +
#    "[2020-01-19 18:53:43.277] DEBUG -- : crawler 0 found 24\n" +
#    "[2020-01-19 18:53:43.278] DEBUG -- : crawler 2 found 25\n" +
#    "[2020-01-19 18:53:43.278] DEBUG -- : crawler 1 found 26\n" +
#    "[2020-01-19 18:53:43.345] DEBUG -- : data-processor 6 got 19\n" +
#    "[2020-01-19 18:53:43.345] DEBUG -- : data-processor 4 got 1a\n" +
#    "[2020-01-19 18:53:43.346] DEBUG -- : data-processor 7 got 1b\n" +
#    "[2020-01-19 18:53:43.353] DEBUG -- : data-processor 5 got 1c\n" +
#    "[2020-01-19 18:53:43.357] DEBUG -- : data-processor 8 got 1d\n" +
#    "[2020-01-19 18:53:43.357] DEBUG -- : crawler 3 found 27\n" +
#    "[2020-01-19 18:53:43.358] DEBUG -- : data-processor 9 got 1e\n" +
#    "[2020-01-19 18:53:43.358] DEBUG -- : data-processor 10 got 1f\n" +
#    "[2020-01-19 18:53:43.358] DEBUG -- : crawler 1 found 28\n" +
#    "[2020-01-19 18:53:43.358] DEBUG -- : crawler 2 found 29\n" +
#    "[2020-01-19 18:53:43.358] DEBUG -- : crawler 0 found 2a\n" +
#    "[2020-01-19 18:53:43.359] DEBUG -- : data-processor 11 got 20\n" +
#    "[2020-01-19 18:53:43.367] DEBUG -- : crawler 1 found 2b\n" +
#    "[2020-01-19 18:53:43.367] DEBUG -- : crawler 2 found 2c\n" +
#    "[2020-01-19 18:53:43.368] DEBUG -- : data-processor 12 got 21\n" +
#    "[2020-01-19 18:53:43.368] DEBUG -- : crawler 3 found 2d\n" +
#    "[2020-01-19 18:53:43.368] DEBUG -- : crawler 0 found 2e\n" +
#    "[2020-01-19 18:53:43.371] DEBUG -- : data-processor 13 got 22\n" +
#    "[2020-01-19 18:53:43.371] DEBUG -- : data-processor 14 got 23\n" +
#    "[2020-01-19 18:53:43.372] DEBUG -- : data-processor 15 got 24\n" +
#    "[2020-01-19 18:53:43.447] DEBUG -- : data-processor 16 got 25\n" +
#    "[2020-01-19 18:53:43.447] DEBUG -- : crawler 2 found 2f\n" +
#    "[2020-01-19 18:53:43.447] DEBUG -- : crawler 3 found 30\n" +
#    "[2020-01-19 18:53:43.448] DEBUG -- : data-processor 18 got 26\n" +
#    "[2020-01-19 18:53:43.448] DEBUG -- : crawler 1 found 31\n" +
#    "[2020-01-19 18:53:43.448] DEBUG -- : crawler 0 found 32\n" +
#    "[2020-01-19 18:53:43.449] DEBUG -- : data-processor 17 got 27\n" +
#    "[2020-01-19 18:53:43.454] DEBUG -- : data-processor 19 got 28\n" +
#    "[2020-01-19 18:53:43.458] DEBUG -- : data-processor 1 got 29\n" +
#    "[2020-01-19 18:53:43.458] DEBUG -- : data-processor 2 got 2a\n" +
#    "[2020-01-19 18:53:43.458] DEBUG -- : crawler 1 found 33\n" +
#    "[2020-01-19 18:53:43.459] DEBUG -- : crawler 2 found 34\n" +
#    "[2020-01-19 18:53:43.459] DEBUG -- : crawler 3 found 35\n" +
#    "[2020-01-19 18:53:43.459] DEBUG -- : crawler 0 found 36\n" +
#    "[2020-01-19 18:53:43.460] DEBUG -- : data-processor 3 got 2b\n" +
#    "[2020-01-19 18:53:43.460] DEBUG -- : data-processor 0 got 2c\n" +
#    "[2020-01-19 18:53:43.468] DEBUG -- : data-processor 6 got 2d\n" +
#    "[2020-01-19 18:53:43.469] DEBUG -- : crawler 3 found 37\n" +
#    "[2020-01-19 18:53:43.469] DEBUG -- : crawler 1 found 38\n" +
#    "[2020-01-19 18:53:43.469] DEBUG -- : crawler 2 found 39\n" +
#    "[2020-01-19 18:53:43.469] DEBUG -- : crawler 0 found 3a\n" +
#    "[2020-01-19 18:53:43.474] DEBUG -- : data-processor 4 got 2e\n" +
#    "[2020-01-19 18:53:43.475] DEBUG -- : data-processor 7 got 2f\n" +
#    "[2020-01-19 18:53:43.476] DEBUG -- : data-processor 5 got 30\n" +
#    "[2020-01-19 18:53:43.479] DEBUG -- : crawler 2 found 3b\n" +
#    "[2020-01-19 18:53:43.479] DEBUG -- : crawler 0 found 3c\n" +
#    "[2020-01-19 18:53:43.480] DEBUG -- : crawler 3 found 3d\n" +
#    "[2020-01-19 18:53:43.482] DEBUG -- : crawler 1 found 3e\n" +
#    "[2020-01-19 18:53:43.529]  INFO -- : \n" +
#    "crawlers found: 16, 15, 15, 16\n" +
#    "data processors consumed: 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2\n" +
#    "[2020-01-19 18:53:43.550] DEBUG -- : data-processor 10 got 31\n" +
#    "[2020-01-19 18:53:43.550] DEBUG -- : data-processor 9 got 32\n" +
#    "[2020-01-19 18:53:43.550] DEBUG -- : data-processor 8 got 33\n" +
#    "[2020-01-19 18:53:43.554] DEBUG -- : data-processor 11 got 34\n" +
#    "[2020-01-19 18:53:43.562] DEBUG -- : data-processor 12 got 35\n" +
#    "[2020-01-19 18:53:43.562] DEBUG -- : data-processor 14 got 36\n" +
#    "[2020-01-19 18:53:43.563] DEBUG -- : crawler 2 found 3f\n" +
#    "[2020-01-19 18:53:43.563] DEBUG -- : crawler 0 found 40\n" +
#    "[2020-01-19 18:53:43.563] DEBUG -- : data-processor 15 got 37\n" +
#    "[2020-01-19 18:53:43.563] DEBUG -- : data-processor 13 got 38\n" +
#    "[2020-01-19 18:53:43.564] DEBUG -- : crawler 3 found 41\n" +
#    "[2020-01-19 18:53:43.564] DEBUG -- : crawler 1 found 42\n" +
#    "[2020-01-19 18:53:43.568] DEBUG -- : data-processor 17 got 39\n" +
#    "[2020-01-19 18:53:43.574] DEBUG -- : crawler 2 found 43\n" +
#    "[2020-01-19 18:53:43.575] DEBUG -- : crawler 0 found 44\n" +
#    "[2020-01-19 18:53:43.575] DEBUG -- : crawler 3 found 45\n" +
#    "[2020-01-19 18:53:43.575] DEBUG -- : crawler 1 found 46\n" +
#    "[2020-01-19 18:53:43.576] DEBUG -- : data-processor 16 got 3a\n" +
#    "[2020-01-19 18:53:43.576] DEBUG -- : data-processor 18 got 3b\n" +
#    "[2020-01-19 18:53:43.581] DEBUG -- : data-processor 19 got 3c\n" +
#    "[2020-01-19 18:53:43.651] DEBUG -- : data-processor 0 got 3d\n" +
#    "[2020-01-19 18:53:43.652] DEBUG -- : crawler 2 found 47\n" +
#    "[2020-01-19 18:53:43.652] DEBUG -- : crawler 3 found 48\n" +
#    "[2020-01-19 18:53:43.652] DEBUG -- : crawler 0 found 49\n" +
#    "[2020-01-19 18:53:43.652] DEBUG -- : crawler 1 found 4a\n" +
#    "[2020-01-19 18:53:43.653] DEBUG -- : data-processor 1 got 3e\n" +
#    "[2020-01-19 18:53:43.653] DEBUG -- : data-processor 2 got 3f\n" +
#    "[2020-01-19 18:53:43.658] DEBUG -- : data-processor 3 got 40\n" +
#    "[2020-01-19 18:53:43.662] DEBUG -- : crawler 3 found 4b\n" +
#    "[2020-01-19 18:53:43.662] DEBUG -- : crawler 0 found 4c\n" +
#    "[2020-01-19 18:53:43.662] DEBUG -- : crawler 1 found 4d\n" +
#    "[2020-01-19 18:53:43.663] DEBUG -- : crawler 2 found 4e\n" +
#    "[2020-01-19 18:53:43.665] DEBUG -- : data-processor 6 got 41\n" +
#    "[2020-01-19 18:53:43.666] DEBUG -- : data-processor 4 got 42\n" +
#    "[2020-01-19 18:53:43.666] DEBUG -- : data-processor 7 got 43\n" +
#    "[2020-01-19 18:53:43.666] DEBUG -- : data-processor 5 got 44\n" +
#    "[2020-01-19 18:53:43.671] DEBUG -- : data-processor 10 got 45\n" +
#    "[2020-01-19 18:53:43.672] DEBUG -- : crawler 3 found 4f\n" +
#    "[2020-01-19 18:53:43.672] DEBUG -- : crawler 0 found 50\n" +
#    "[2020-01-19 18:53:43.673] DEBUG -- : crawler 1 found 51\n" +
#    "[2020-01-19 18:53:43.673] DEBUG -- : crawler 2 found 52\n" +
#    "[2020-01-19 18:53:43.676] DEBUG -- : data-processor 8 got 46\n" +
#    "[2020-01-19 18:53:43.677] DEBUG -- : data-processor 9 got 47\n" +
#    "[2020-01-19 18:53:43.682] DEBUG -- : data-processor 11 got 48\n" +
#    "[2020-01-19 18:53:43.683] DEBUG -- : crawler 3 found 53\n" +
#    "[2020-01-19 18:53:43.683] DEBUG -- : crawler 1 found 54\n" +
#    "[2020-01-19 18:53:43.684] DEBUG -- : crawler 0 found 55\n" +
#    "[2020-01-19 18:53:43.684] DEBUG -- : crawler 2 found 56\n" +
#    "[2020-01-19 18:53:43.754] DEBUG -- : data-processor 15 got 49\n" +
#    "[2020-01-19 18:53:43.754] DEBUG -- : data-processor 14 got 4a\n" +
#    "[2020-01-19 18:53:43.755] DEBUG -- : data-processor 13 got 4b\n" +
#    "[2020-01-19 18:53:43.759] DEBUG -- : data-processor 12 got 4c\n" +
#    "[2020-01-19 18:53:43.767] DEBUG -- : data-processor 17 got 4d\n" +
#    "[2020-01-19 18:53:43.768] DEBUG -- : data-processor 16 got 4e\n" +
#    "[2020-01-19 18:53:43.768] DEBUG -- : crawler 1 found 57\n" +
#    "[2020-01-19 18:53:43.768] DEBUG -- : data-processor 18 got 4f\n" +
#    "[2020-01-19 18:53:43.769] DEBUG -- : crawler 0 found 58\n" +
#    "[2020-01-19 18:53:43.769] DEBUG -- : crawler 3 found 59\n" +
#    "[2020-01-19 18:53:43.770] DEBUG -- : data-processor 19 got 50\n" +
#    "[2020-01-19 18:53:43.770] DEBUG -- : crawler 2 found 5a\n" +
#    "[2020-01-19 18:53:43.776] DEBUG -- : data-processor 0 got 51\n" +
#    "[2020-01-19 18:53:43.780] DEBUG -- : crawler 1 found 5b\n" +
#    "[2020-01-19 18:53:43.780] DEBUG -- : crawler 0 found 5c\n" +
#    "[2020-01-19 18:53:43.780] DEBUG -- : crawler 3 found 5d\n" +
#    "[2020-01-19 18:53:43.781] DEBUG -- : crawler 2 found 5e\n" +
#    "[2020-01-19 18:53:43.781] DEBUG -- : data-processor 1 got 52\n" +
#    "[2020-01-19 18:53:43.782] DEBUG -- : data-processor 2 got 53\n" +
#    "[2020-01-19 18:53:43.783] DEBUG -- : data-processor 3 got 54\n" +
#    "[2020-01-19 18:53:43.858] DEBUG -- : data-processor 4 got 55\n" +
#    "[2020-01-19 18:53:43.859] DEBUG -- : data-processor 5 got 56\n" +
#    "[2020-01-19 18:53:43.859] DEBUG -- : data-processor 7 got 57\n" +
#    "[2020-01-19 18:53:43.860] DEBUG -- : crawler 1 found 5f\n" +
#    "[2020-01-19 18:53:43.860] DEBUG -- : crawler 3 found 60\n" +
#    "[2020-01-19 18:53:43.860] DEBUG -- : crawler 0 found 61\n" +
#    "[2020-01-19 18:53:43.861] DEBUG -- : crawler 2 found 62\n" +
#    "[2020-01-19 18:53:43.861] DEBUG -- : data-processor 6 got 58\n" +
#    "[2020-01-19 18:53:43.869] DEBUG -- : crawler 1 found 63\n" +
#    "[2020-01-19 18:53:43.869] DEBUG -- : crawler 3 found 64\n" +
#    "[2020-01-19 18:53:43.870] DEBUG -- : crawler 0 found 65\n" +
#    "[2020-01-19 18:53:43.870] DEBUG -- : data-processor 10 got 59\n" +
#    "[2020-01-19 18:53:43.871] DEBUG -- : data-processor 8 got 5a\n" +
#    "[2020-01-19 18:53:43.871] DEBUG -- : data-processor 9 got 5b\n" +
#    "[2020-01-19 18:53:43.872] DEBUG -- : crawler 2 found 66\n" +
#    "[2020-01-19 18:53:43.872] DEBUG -- : data-processor 11 got 5c\n" +
#    "[2020-01-19 18:53:43.884] DEBUG -- : data-processor 14 got 5d\n" +
#    "[2020-01-19 18:53:43.884] DEBUG -- : crawler 3 found 68\n" +
#    "[2020-01-19 18:53:43.884] DEBUG -- : crawler 2 found 69\n" +
#    "[2020-01-19 18:53:43.885] DEBUG -- : crawler 0 found 6a\n" +
#    "[2020-01-19 18:53:43.885] DEBUG -- : crawler 1 found 67\n" +
#    "[2020-01-19 18:53:43.885] DEBUG -- : data-processor 15 got 5e\n" +
#    "[2020-01-19 18:53:43.885] DEBUG -- : data-processor 13 got 5f\n" +
#    "[2020-01-19 18:53:43.887] DEBUG -- : data-processor 12 got 60\n" +
#    "[2020-01-19 18:53:43.894] DEBUG -- : crawler 3 found 6b\n" +
#    "[2020-01-19 18:53:43.894] DEBUG -- : crawler 2 found 6c\n" +
#    "[2020-01-19 18:53:43.895] DEBUG -- : crawler 0 found 6d\n" +
#    "[2020-01-19 18:53:43.895] DEBUG -- : crawler 1 found 6e\n" +
#    "[2020-01-19 18:53:43.932]  INFO -- : \n" +
#    "crawlers found: 28, 27, 27, 28\n" +
#    "data processors consumed: 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4\n" +
#    "[2020-01-19 18:53:43.958] DEBUG -- : data-processor 16 got 61\n" +
#    "[2020-01-19 18:53:43.958] DEBUG -- : data-processor 19 got 62\n" +
#    "[2020-01-19 18:53:43.959] DEBUG -- : data-processor 17 got 63\n" +
#    "[2020-01-19 18:53:43.959] DEBUG -- : data-processor 18 got 64\n" +
#    "[2020-01-19 18:53:43.970] DEBUG -- : data-processor 0 got 65\n" +
#    "[2020-01-19 18:53:43.970] DEBUG -- : data-processor 1 got 66\n" +
#    "[2020-01-19 18:53:43.970] DEBUG -- : data-processor 2 got 67\n" +
#    "[2020-01-19 18:53:43.971] DEBUG -- : crawler 3 found 6f\n" +
#    "[2020-01-19 18:53:43.971] DEBUG -- : crawler 2 found 70\n" +
#    "[2020-01-19 18:53:43.971] DEBUG -- : crawler 0 found 71\n" +
#    "[2020-01-19 18:53:43.971] DEBUG -- : data-processor 3 got 68\n" +
#    "[2020-01-19 18:53:43.971] DEBUG -- : crawler 1 found 72\n" +
#    "[2020-01-19 18:53:43.982] DEBUG -- : crawler 3 found 73\n" +
#    "[2020-01-19 18:53:43.982] DEBUG -- : crawler 2 found 74\n" +
#    "[2020-01-19 18:53:43.983] DEBUG -- : crawler 1 found 75\n" +
#    "[2020-01-19 18:53:43.983] DEBUG -- : crawler 0 found 76\n" +
#    "[2020-01-19 18:53:43.988] DEBUG -- : data-processor 4 got 69\n" +
#    "[2020-01-19 18:53:43.989] DEBUG -- : data-processor 5 got 6a\n" +
#    "[2020-01-19 18:53:43.989] DEBUG -- : data-processor 7 got 6b\n" +
#    "[2020-01-19 18:53:43.990] DEBUG -- : data-processor 6 got 6c\n" +
#    "[2020-01-19 18:53:44.062] DEBUG -- : data-processor 8 got 6d\n" +
#    "[2020-01-19 18:53:44.062] DEBUG -- : crawler 3 found 77\n" +
#    "[2020-01-19 18:53:44.063] DEBUG -- : crawler 2 found 78\n" +
#    "[2020-01-19 18:53:44.063] DEBUG -- : crawler 1 found 79\n" +
#    "[2020-01-19 18:53:44.063] DEBUG -- : crawler 0 found 7a\n" +
#    "[2020-01-19 18:53:44.063] DEBUG -- : data-processor 11 got 6e\n" +
#    "[2020-01-19 18:53:44.064] DEBUG -- : data-processor 9 got 6f\n" +
#    "[2020-01-19 18:53:44.064] DEBUG -- : data-processor 10 got 70\n" +
#    "[2020-01-19 18:53:44.074] DEBUG -- : data-processor 15 got 71\n" +
#    "[2020-01-19 18:53:44.074] DEBUG -- : data-processor 14 got 72\n" +
#    "[2020-01-19 18:53:44.074] DEBUG -- : data-processor 13 got 73\n" +
#    "[2020-01-19 18:53:44.075] DEBUG -- : data-processor 12 got 74\n" +
#    "[2020-01-19 18:53:44.075] DEBUG -- : crawler 3 found 7b\n" +
#    "[2020-01-19 18:53:44.075] DEBUG -- : crawler 2 found 7c\n" +
#    "[2020-01-19 18:53:44.075] DEBUG -- : crawler 1 found 7d\n" +
#    "[2020-01-19 18:53:44.075] DEBUG -- : crawler 0 found 7e\n" +
#    "[2020-01-19 18:53:44.089] DEBUG -- : data-processor 16 got 75\n" +
#    "[2020-01-19 18:53:44.090] DEBUG -- : data-processor 17 got 76\n" +
#    "[2020-01-19 18:53:44.090] DEBUG -- : crawler 3 found 7f\n" +
#    "[2020-01-19 18:53:44.090] DEBUG -- : crawler 2 found 80\n" +
#    "[2020-01-19 18:53:44.091] DEBUG -- : crawler 1 found 81\n" +
#    "[2020-01-19 18:53:44.091] DEBUG -- : crawler 0 found 82\n" +
#    "[2020-01-19 18:53:44.091] DEBUG -- : data-processor 19 got 77\n" +
#    "[2020-01-19 18:53:44.091] DEBUG -- : data-processor 18 got 78\n" +
#    "[2020-01-19 18:53:44.100] DEBUG -- : crawler 3 found 83\n" +
#    "[2020-01-19 18:53:44.100] DEBUG -- : crawler 2 found 84\n" +
#    "[2020-01-19 18:53:44.100] DEBUG -- : crawler 1 found 85\n" +
#    "[2020-01-19 18:53:44.100] DEBUG -- : crawler 0 found 86\n" +
#    "[2020-01-19 18:53:44.162] DEBUG -- : data-processor 2 got 79\n" +
#    "[2020-01-19 18:53:44.163] DEBUG -- : data-processor 0 got 7a\n" +
#    "[2020-01-19 18:53:44.163] DEBUG -- : data-processor 1 got 7b\n" +
#    "[2020-01-19 18:53:44.163] DEBUG -- : data-processor 3 got 7c\n" +
#    "[2020-01-19 18:53:44.175] DEBUG -- : data-processor 4 got 7d\n" +
#    "[2020-01-19 18:53:44.175] DEBUG -- : crawler 3 found 87\n" +
#    "[2020-01-19 18:53:44.176] DEBUG -- : crawler 2 found 88\n" +
#    "[2020-01-19 18:53:44.176] DEBUG -- : crawler 0 found 89\n" +
#    "[2020-01-19 18:53:44.176] DEBUG -- : crawler 1 found 8a\n" +
#    "[2020-01-19 18:53:44.176] DEBUG -- : data-processor 5 got 7e\n" +
#    "[2020-01-19 18:53:44.177] DEBUG -- : data-processor 7 got 7f\n" +
#    "[2020-01-19 18:53:44.177] DEBUG -- : data-processor 6 got 80\n" +
#    "[2020-01-19 18:53:44.186] DEBUG -- : crawler 0 found 8b\n" +
#    "[2020-01-19 18:53:44.186] DEBUG -- : crawler 1 found 8c\n" +
#    "[2020-01-19 18:53:44.187] DEBUG -- : crawler 2 found 8d\n" +
#    "[2020-01-19 18:53:44.187] DEBUG -- : crawler 3 found 8e\n" +
#    "[2020-01-19 18:53:44.191] DEBUG -- : data-processor 8 got 81\n" +
#    "[2020-01-19 18:53:44.192] DEBUG -- : data-processor 9 got 82\n" +
#    "[2020-01-19 18:53:44.192] DEBUG -- : data-processor 11 got 83\n" +
#    "[2020-01-19 18:53:44.192] DEBUG -- : data-processor 10 got 84\n" +
#    "[2020-01-19 18:53:44.263] DEBUG -- : data-processor 15 got 85\n" +
#    "[2020-01-19 18:53:44.264] DEBUG -- : data-processor 12 got 86\n" +
#    "[2020-01-19 18:53:44.264] DEBUG -- : crawler 3 found 8f\n" +
#    "[2020-01-19 18:53:44.264] DEBUG -- : crawler 0 found 90\n" +
#    "[2020-01-19 18:53:44.266] DEBUG -- : crawler 1 found 91\n" +
#    "[2020-01-19 18:53:44.266] DEBUG -- : crawler 2 found 92\n" +
#    "[2020-01-19 18:53:44.266] DEBUG -- : data-processor 14 got 87\n" +
#    "[2020-01-19 18:53:44.267] DEBUG -- : data-processor 13 got 88\n" +
#    "[2020-01-19 18:53:44.274] DEBUG -- : crawler 3 found 93\n" +
#    "[2020-01-19 18:53:44.274] DEBUG -- : crawler 0 found 94\n" +
#    "[2020-01-19 18:53:44.274] DEBUG -- : crawler 2 found 95\n" +
#    "[2020-01-19 18:53:44.274] DEBUG -- : crawler 1 found 96\n" +
#    "[2020-01-19 18:53:44.276] DEBUG -- : data-processor 17 got 89\n" +
#    "[2020-01-19 18:53:44.276] DEBUG -- : data-processor 16 got 8a\n" +
#    "[2020-01-19 18:53:44.278] DEBUG -- : data-processor 19 got 8b\n" +
#    "[2020-01-19 18:53:44.278] DEBUG -- : data-processor 18 got 8c\n" +
#    "[2020-01-19 18:53:44.292] DEBUG -- : data-processor 0 got 8d\n" +
#    "[2020-01-19 18:53:44.293] DEBUG -- : crawler 0 found 97\n" +
#    "[2020-01-19 18:53:44.293] DEBUG -- : crawler 2 found 98\n" +
#    "[2020-01-19 18:53:44.293] DEBUG -- : crawler 1 found 99\n" +
#    "[2020-01-19 18:53:44.294] DEBUG -- : crawler 3 found 9a\n" +
#    "[2020-01-19 18:53:44.294] DEBUG -- : data-processor 1 got 8e\n" +
#    "[2020-01-19 18:53:44.294] DEBUG -- : data-processor 3 got 8f\n" +
#    "[2020-01-19 18:53:44.294] DEBUG -- : data-processor 2 got 90\n" +
#    "[2020-01-19 18:53:44.304] DEBUG -- : crawler 1 found 9b\n" +
#    "[2020-01-19 18:53:44.304] DEBUG -- : crawler 3 found 9c\n" +
#    "[2020-01-19 18:53:44.304] DEBUG -- : crawler 0 found 9d\n" +
#    "[2020-01-19 18:53:44.304] DEBUG -- : crawler 2 found 9e\n" +
#    "[2020-01-19 18:53:44.337]  INFO -- : \n" +
#    "crawlers found: 40, 39, 39, 40\n" +
#    "data processors consumed: 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7\n" +
#    "[2020-01-19 18:53:44.364] DEBUG -- : data-processor 6 got 91\n" +
#    "[2020-01-19 18:53:44.364] DEBUG -- : data-processor 5 got 92\n" +
#    "[2020-01-19 18:53:44.364] DEBUG -- : data-processor 4 got 93\n" +
#    "[2020-01-19 18:53:44.364] DEBUG -- : data-processor 7 got 94\n" +
#    "[2020-01-19 18:53:44.377] DEBUG -- : data-processor 8 got 95\n" +
#    "[2020-01-19 18:53:44.377] DEBUG -- : data-processor 10 got 96\n" +
#    "[2020-01-19 18:53:44.377] DEBUG -- : crawler 1 found 9f\n" +
#    "[2020-01-19 18:53:44.378] DEBUG -- : crawler 3 found a0\n" +
#    "[2020-01-19 18:53:44.378] DEBUG -- : crawler 0 found a1\n" +
#    "[2020-01-19 18:53:44.378] DEBUG -- : crawler 2 found a2\n" +
#    "[2020-01-19 18:53:44.378] DEBUG -- : data-processor 9 got 97\n" +
#    "[2020-01-19 18:53:44.383] DEBUG -- : data-processor 11 got 98\n" +
#    "[2020-01-19 18:53:44.387] DEBUG -- : crawler 3 found a3\n" +
#    "[2020-01-19 18:53:44.387] DEBUG -- : crawler 0 found a4\n" +
#    "[2020-01-19 18:53:44.387] DEBUG -- : crawler 1 found a5\n" +
#    "[2020-01-19 18:53:44.388] DEBUG -- : crawler 2 found a6\n" +
#    "[2020-01-19 18:53:44.393] DEBUG -- : data-processor 15 got 99\n" +
#    "[2020-01-19 18:53:44.393] DEBUG -- : data-processor 12 got 9a\n" +
#    "[2020-01-19 18:53:44.393] DEBUG -- : data-processor 14 got 9b\n" +
#    "[2020-01-19 18:53:44.394] DEBUG -- : data-processor 13 got 9c\n" +
#    "[2020-01-19 18:53:44.466] DEBUG -- : data-processor 17 got 9d\n" +
#    "[2020-01-19 18:53:44.466] DEBUG -- : data-processor 16 got 9e\n" +
#    "[2020-01-19 18:53:44.466] DEBUG -- : data-processor 19 got 9f\n" +
#    "[2020-01-19 18:53:44.467] DEBUG -- : data-processor 18 got a0\n" +
#    "[2020-01-19 18:53:44.467] DEBUG -- : crawler 0 found a7\n" +
#    "[2020-01-19 18:53:44.467] DEBUG -- : crawler 2 found a8\n" +
#    "[2020-01-19 18:53:44.467] DEBUG -- : crawler 1 found a9\n" +
#    "[2020-01-19 18:53:44.468] DEBUG -- : crawler 3 found aa\n" +
#    "[2020-01-19 18:53:44.476] DEBUG -- : crawler 2 found ab\n" +
#    "[2020-01-19 18:53:44.476] DEBUG -- : crawler 0 found ac\n" +
#    "[2020-01-19 18:53:44.476] DEBUG -- : crawler 3 found ad\n" +
#    "[2020-01-19 18:53:44.477] DEBUG -- : crawler 1 found ae\n" +
#    "[2020-01-19 18:53:44.477] DEBUG -- : data-processor 0 got a1\n" +
#    "[2020-01-19 18:53:44.477] DEBUG -- : data-processor 1 got a2\n" +
#    "[2020-01-19 18:53:44.479] DEBUG -- : data-processor 3 got a3\n" +
#    "[2020-01-19 18:53:44.483] DEBUG -- : data-processor 2 got a4\n" +
#    "[2020-01-19 18:53:44.494] DEBUG -- : data-processor 6 got a5\n" +
#    "[2020-01-19 18:53:44.494] DEBUG -- : crawler 1 found af\n" +
#    "[2020-01-19 18:53:44.494] DEBUG -- : data-processor 5 got a6\n" +
#    "[2020-01-19 18:53:44.494] DEBUG -- : crawler 0 found b0\n" +
#    "[2020-01-19 18:53:44.495] DEBUG -- : crawler 2 found b1\n" +
#    "[2020-01-19 18:53:44.495] DEBUG -- : crawler 3 found b2\n" +
#    "[2020-01-19 18:53:44.495] DEBUG -- : data-processor 4 got a7\n" +
#    "[2020-01-19 18:53:44.495] DEBUG -- : data-processor 7 got a8\n" +
#    "[2020-01-19 18:53:44.504] DEBUG -- : crawler 2 found b3\n" +
#    "[2020-01-19 18:53:44.504] DEBUG -- : crawler 1 found b4\n" +
#    "[2020-01-19 18:53:44.505] DEBUG -- : crawler 3 found b5\n" +
#    "[2020-01-19 18:53:44.505] DEBUG -- : crawler 0 found b6\n" +
#    "[2020-01-19 18:53:44.567] DEBUG -- : data-processor 8 got a9\n" +
#    "[2020-01-19 18:53:44.567] DEBUG -- : data-processor 10 got aa\n" +
#    "[2020-01-19 18:53:44.569] DEBUG -- : data-processor 9 got ab\n" +
#    "[2020-01-19 18:53:44.569] DEBUG -- : data-processor 11 got ac\n" +
#    "[2020-01-19 18:53:44.583] DEBUG -- : data-processor 15 got ad\n" +
#    "[2020-01-19 18:53:44.584] DEBUG -- : data-processor 12 got ae\n" +
#    "[2020-01-19 18:53:44.584] DEBUG -- : data-processor 14 got af\n" +
#    "[2020-01-19 18:53:44.584] DEBUG -- : crawler 3 found b7\n" +
#    "[2020-01-19 18:53:44.584] DEBUG -- : crawler 2 found b8\n" +
#    "[2020-01-19 18:53:44.585] DEBUG -- : crawler 0 found b9\n" +
#    "[2020-01-19 18:53:44.585] DEBUG -- : crawler 1 found ba\n" +
#    "[2020-01-19 18:53:44.587] DEBUG -- : data-processor 13 got b0\n" +
#    "[2020-01-19 18:53:44.594] DEBUG -- : data-processor 19 got b1\n" +
#    "[2020-01-19 18:53:44.595] DEBUG -- : data-processor 16 got b2\n" +
#    "[2020-01-19 18:53:44.595] DEBUG -- : data-processor 17 got b3\n" +
#    "[2020-01-19 18:53:44.595] DEBUG -- : data-processor 18 got b4\n" +
#    "[2020-01-19 18:53:44.596] DEBUG -- : crawler 3 found bb\n" +
#    "[2020-01-19 18:53:44.596] DEBUG -- : crawler 0 found bc\n" +
#    "[2020-01-19 18:53:44.596] DEBUG -- : crawler 2 found bd\n" +
#    "[2020-01-19 18:53:44.596] DEBUG -- : crawler 1 found be\n" +
#    "[2020-01-19 18:53:44.670] DEBUG -- : data-processor 0 got b5\n" +
#    "[2020-01-19 18:53:44.671] DEBUG -- : data-processor 1 got b6\n" +
#    "[2020-01-19 18:53:44.671] DEBUG -- : crawler 3 found bf\n" +
#    "[2020-01-19 18:53:44.671] DEBUG -- : crawler 0 found c0\n" +
#    "[2020-01-19 18:53:44.672] DEBUG -- : crawler 2 found c1\n" +
#    "[2020-01-19 18:53:44.672] DEBUG -- : crawler 1 found c2\n" +
#    "[2020-01-19 18:53:44.672] DEBUG -- : data-processor 3 got b7\n" +
#    "[2020-01-19 18:53:44.672] DEBUG -- : data-processor 2 got b8\n" +
#    "[2020-01-19 18:53:44.681] DEBUG -- : crawler 3 found c3\n" +
#    "[2020-01-19 18:53:44.681] DEBUG -- : crawler 0 found c4\n" +
#    "[2020-01-19 18:53:44.682] DEBUG -- : crawler 2 found c5\n" +
#    "[2020-01-19 18:53:44.682] DEBUG -- : crawler 1 found c6\n" +
#    "[2020-01-19 18:53:44.683] DEBUG -- : data-processor 5 got b9\n" +
#    "[2020-01-19 18:53:44.684] DEBUG -- : data-processor 4 got ba\n" +
#    "[2020-01-19 18:53:44.687] DEBUG -- : data-processor 7 got bb\n" +
#    "[2020-01-19 18:53:44.688] DEBUG -- : data-processor 6 got bc\n" +
#    "[2020-01-19 18:53:44.695] DEBUG -- : data-processor 9 got bd\n" +
#    "[2020-01-19 18:53:44.695] DEBUG -- : crawler 0 found c7\n" +
#    "[2020-01-19 18:53:44.696] DEBUG -- : crawler 2 found c8\n" +
#    "[2020-01-19 18:53:44.696] DEBUG -- : crawler 1 found c9\n" +
#    "[2020-01-19 18:53:44.696] DEBUG -- : crawler 3 found ca\n" +
#    "[2020-01-19 18:53:44.696] DEBUG -- : data-processor 11 got be\n" +
#    "[2020-01-19 18:53:44.696] DEBUG -- : data-processor 8 got bf\n" +
#    "[2020-01-19 18:53:44.697] DEBUG -- : data-processor 10 got c0\n" +
#    "[2020-01-19 18:53:44.705] DEBUG -- : crawler 3 found cb\n" +
#    "[2020-01-19 18:53:44.706] DEBUG -- : crawler 1 found cc\n" +
#    "[2020-01-19 18:53:44.706] DEBUG -- : crawler 0 found cd\n" +
#    "[2020-01-19 18:53:44.706] DEBUG -- : crawler 2 found ce\n" +
#    "[2020-01-19 18:53:44.738]  INFO -- : \n" +
#    "crawlers found: 52, 51, 51, 52\n" +
#    "data processors consumed: 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9, 9\n" +
#    "[2020-01-19 18:53:44.771] DEBUG -- : data-processor 15 got c1\n" +
#    "[2020-01-19 18:53:44.772] DEBUG -- : data-processor 14 got c2\n" +
#    "[2020-01-19 18:53:44.772] DEBUG -- : data-processor 12 got c3\n" +
#    "[2020-01-19 18:53:44.772] DEBUG -- : data-processor 13 got c4\n" +
#    "[2020-01-19 18:53:44.788] DEBUG -- : data-processor 19 got c5\n" +
#    "[2020-01-19 18:53:44.789] DEBUG -- : crawler 3 found cf\n" +
#    "[2020-01-19 18:53:44.789] DEBUG -- : crawler 1 found d0\n" +
#    "[2020-01-19 18:53:44.789] DEBUG -- : crawler 2 found d1\n" +
#    "[2020-01-19 18:53:44.790] DEBUG -- : crawler 0 found d2\n" +
#    "[2020-01-19 18:53:44.790] DEBUG -- : data-processor 18 got c6\n" +
#    "[2020-01-19 18:53:44.791] DEBUG -- : data-processor 16 got c7\n" +
#    "[2020-01-19 18:53:44.791] DEBUG -- : data-processor 17 got c8\n" +
#    "[2020-01-19 18:53:44.795] DEBUG -- : data-processor 1 got c9\n" +
#    "[2020-01-19 18:53:44.798] DEBUG -- : data-processor 2 got ca\n" +
#    "[2020-01-19 18:53:44.798] DEBUG -- : data-processor 0 got cb\n" +
#    "[2020-01-19 18:53:44.798] DEBUG -- : data-processor 3 got cc\n" +
#    "[2020-01-19 18:53:44.799] DEBUG -- : crawler 1 found d3\n" +
#    "[2020-01-19 18:53:44.799] DEBUG -- : crawler 2 found d4\n" +
#    "[2020-01-19 18:53:44.799] DEBUG -- : crawler 0 found d5\n" +
#    "[2020-01-19 18:53:44.800] DEBUG -- : crawler 3 found d6\n" +
#    "[2020-01-19 18:53:44.872] DEBUG -- : data-processor 4 got cd\n" +
#    "[2020-01-19 18:53:44.873] DEBUG -- : crawler 0 found d7\n" +
#    "[2020-01-19 18:53:44.873] DEBUG -- : crawler 1 found d8\n" +
#    "[2020-01-19 18:53:44.874] DEBUG -- : crawler 2 found d9\n" +
#    "[2020-01-19 18:53:44.874] DEBUG -- : crawler 3 found da\n" +
#    "[2020-01-19 18:53:44.874] DEBUG -- : data-processor 5 got ce\n" +
#    "[2020-01-19 18:53:44.875] DEBUG -- : data-processor 7 got cf\n" +
#    "[2020-01-19 18:53:44.875] DEBUG -- : data-processor 6 got d0\n" +
#    "[2020-01-19 18:53:44.883] DEBUG -- : crawler 0 found db\n" +
#    "[2020-01-19 18:53:44.883] DEBUG -- : crawler 1 found dc\n" +
#    "[2020-01-19 18:53:44.883] DEBUG -- : crawler 2 found dd\n" +
#    "[2020-01-19 18:53:44.884] DEBUG -- : crawler 3 found de\n" +
#    "[2020-01-19 18:53:44.888] DEBUG -- : data-processor 9 got d1\n" +
#    "[2020-01-19 18:53:44.889] DEBUG -- : data-processor 8 got d2\n" +
#    "[2020-01-19 18:53:44.889] DEBUG -- : data-processor 10 got d3\n" +
#    "[2020-01-19 18:53:44.891] DEBUG -- : data-processor 11 got d4\n" +
#    "[2020-01-19 18:53:44.897] DEBUG -- : data-processor 14 got d5\n" +
#    "[2020-01-19 18:53:44.897] DEBUG -- : crawler 0 found df\n" +
#    "[2020-01-19 18:53:44.898] DEBUG -- : crawler 2 found e0\n" +
#    "[2020-01-19 18:53:44.898] DEBUG -- : crawler 3 found e1\n" +
#    "[2020-01-19 18:53:44.899] DEBUG -- : crawler 1 found e2\n" +
#    "[2020-01-19 18:53:44.899] DEBUG -- : data-processor 12 got d6\n" +
#    "[2020-01-19 18:53:44.901] DEBUG -- : data-processor 15 got d7\n" +
#    "[2020-01-19 18:53:44.901] DEBUG -- : data-processor 13 got d8\n" +
#    "[2020-01-19 18:53:44.907] DEBUG -- : crawler 2 found e3\n" +
#    "[2020-01-19 18:53:44.908] DEBUG -- : crawler 3 found e4\n" +
#    "[2020-01-19 18:53:44.909] DEBUG -- : crawler 1 found e5\n" +
#    "[2020-01-19 18:53:44.909] DEBUG -- : crawler 0 found e6\n" +
#    "[2020-01-19 18:53:44.973] DEBUG -- : data-processor 19 got d9\n" +
#    "[2020-01-19 18:53:44.974] DEBUG -- : data-processor 18 got da\n" +
#    "[2020-01-19 18:53:44.974] DEBUG -- : data-processor 17 got db\n" +
#    "[2020-01-19 18:53:44.974] DEBUG -- : data-processor 16 got dc\n" +
#    "[2020-01-19 18:53:44.991] DEBUG -- : data-processor 0 got dd\n" +
#    "[2020-01-19 18:53:44.992] DEBUG -- : data-processor 1 got de\n" +
#    "[2020-01-19 18:53:44.992] DEBUG -- : crawler 2 found e7\n" +
#    "[2020-01-19 18:53:44.992] DEBUG -- : crawler 0 found e8\n" +
#    "[2020-01-19 18:53:44.993] DEBUG -- : crawler 3 found e9\n" +
#    "[2020-01-19 18:53:44.993] DEBUG -- : data-processor 2 got df\n" +
#    "[2020-01-19 18:53:44.994] DEBUG -- : crawler 1 found ea\n" +
#    "[2020-01-19 18:53:44.994] DEBUG -- : data-processor 3 got e0\n" +
#    "[2020-01-19 18:53:44.997] DEBUG -- : data-processor 4 got e1\n" +
#    "[2020-01-19 18:53:45.001] DEBUG -- : crawler 0 found eb\n" +
#    "[2020-01-19 18:53:45.001] DEBUG -- : crawler 3 found ec\n" +
#    "[2020-01-19 18:53:45.002] DEBUG -- : crawler 1 found ed\n" +
#    "[2020-01-19 18:53:45.002] DEBUG -- : crawler 2 found ee\n" +
#    "[2020-01-19 18:53:45.004] DEBUG -- : data-processor 5 got e2\n" +
#    "[2020-01-19 18:53:45.004] DEBUG -- : data-processor 7 got e3\n" +
#    "[2020-01-19 18:53:45.005] DEBUG -- : data-processor 6 got e4\n" +
#    "[2020-01-19 18:53:45.074] DEBUG -- : data-processor 8 got e5\n" +
#    "[2020-01-19 18:53:45.074] DEBUG -- : data-processor 9 got e6\n" +
#    "[2020-01-19 18:53:45.074] DEBUG -- : crawler 0 found ef\n" +
#    "[2020-01-19 18:53:45.075] DEBUG -- : crawler 3 found f0\n" +
#    "[2020-01-19 18:53:45.075] DEBUG -- : crawler 1 found f1\n" +
#    "[2020-01-19 18:53:45.075] DEBUG -- : crawler 2 found f2\n" +
#    "[2020-01-19 18:53:45.076] DEBUG -- : data-processor 10 got e7\n" +
#    "[2020-01-19 18:53:45.078] DEBUG -- : data-processor 11 got e8\n" +
#    "[2020-01-19 18:53:45.085] DEBUG -- : crawler 3 found f3\n" +
#    "[2020-01-19 18:53:45.085] DEBUG -- : crawler 0 found f4\n" +
#    "[2020-01-19 18:53:45.086] DEBUG -- : crawler 1 found f5\n" +
#    "[2020-01-19 18:53:45.086] DEBUG -- : crawler 2 found f6\n" +
#    "[2020-01-19 18:53:45.091] DEBUG -- : data-processor 14 got e9\n" +
#    "[2020-01-19 18:53:45.091] DEBUG -- : data-processor 13 got ea\n" +
#    "[2020-01-19 18:53:45.091] DEBUG -- : data-processor 12 got eb\n" +
#    "[2020-01-19 18:53:45.092] DEBUG -- : data-processor 15 got ec\n" +
#    "[2020-01-19 18:53:45.100] DEBUG -- : data-processor 18 got ed\n" +
#    "[2020-01-19 18:53:45.101] DEBUG -- : crawler 3 found f7\n" +
#    "[2020-01-19 18:53:45.101] DEBUG -- : crawler 0 found f8\n" +
#    "[2020-01-19 18:53:45.101] DEBUG -- : crawler 2 found f9\n" +
#    "[2020-01-19 18:53:45.101] DEBUG -- : crawler 1 found fa\n" +
#    "[2020-01-19 18:53:45.104] DEBUG -- : data-processor 17 got ee\n" +
#    "[2020-01-19 18:53:45.104] DEBUG -- : data-processor 19 got ef\n" +
#    "[2020-01-19 18:53:45.107] DEBUG -- : data-processor 16 got f0\n" +
#    "[2020-01-19 18:53:45.110] DEBUG -- : crawler 1 found fb\n" +
#    "[2020-01-19 18:53:45.113] DEBUG -- : crawler 3 found fc\n" +
#    "[2020-01-19 18:53:45.113] DEBUG -- : crawler 0 found fd\n" +
#    "[2020-01-19 18:53:45.113] DEBUG -- : crawler 2 found fe\n" +
#    "[2020-01-19 18:53:45.133]  INFO -- : \n" +
#    "crawlers found: 64, 63, 63, 64\n" +
#    "data processors consumed: 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12\n" +
#    "[2020-01-19 18:53:45.174] DEBUG -- : data-processor 0 got f1\n" +
#    "[2020-01-19 18:53:45.175] DEBUG -- : data-processor 1 got f2\n" +
#    "[2020-01-19 18:53:45.175] DEBUG -- : data-processor 2 got f3\n" +
#    "[2020-01-19 18:53:45.178] DEBUG -- : data-processor 3 got f4\n" +
#    "[2020-01-19 18:53:45.224] DEBUG -- : crawler 1 found ff\n" +
#    "[2020-01-19 18:53:45.225] DEBUG -- : crawler 2 found 101\n" +
#    "[2020-01-19 18:53:45.225] DEBUG -- : crawler 3 found 102\n" +
#    "[2020-01-19 18:53:45.225] DEBUG -- : crawler 0 found 100\n"




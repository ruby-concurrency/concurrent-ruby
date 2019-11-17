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
# => "[2019-11-17 16:32:03.468] FATAL -- : :tornado\n" +
#    "[2019-11-17 16:32:03.469]  INFO -- : :breeze\n"

# the logging could be wrapped in a method
def log(severity, message)
  LOGGING.tell Log[severity, message]
  true
end                                      # => :log

include Logger::Severity                 # => Object
log INFO, 'alive'                        # => true
sleep 0.05                               # => 0
get_captured_output
# => "[2019-11-17 16:32:03.520]  INFO -- : alive\n"


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
#     "1"=>18,
#     "3"=>18,
#     "4"=>18,
#     "7"=>18,
#     "5"=>18,
#     "6"=>18,
#     "8"=>18,
#     "9"=>18,
#     "a"=>18,
#     "b"=>18,
#     "c"=>18,
#     "d"=>18,
#     "e"=>10,
#     "f"=>1}

# see the logger output
get_captured_output
# => "[2019-11-17 16:32:03.596] DEBUG -- : crawler 0 found 1\n" +
#    "[2019-11-17 16:32:03.597] DEBUG -- : crawler 2 found 2\n" +
#    "[2019-11-17 16:32:03.597] DEBUG -- : data-processor 1 got 2\n" +
#    "[2019-11-17 16:32:03.598] DEBUG -- : crawler 1 found 3\n" +
#    "[2019-11-17 16:32:03.598] DEBUG -- : crawler 3 found 4\n" +
#    "[2019-11-17 16:32:03.599] DEBUG -- : data-processor 0 got 1\n" +
#    "[2019-11-17 16:32:03.599] DEBUG -- : data-processor 2 got 3\n" +
#    "[2019-11-17 16:32:03.600] DEBUG -- : data-processor 3 got 4\n" +
#    "[2019-11-17 16:32:03.608] DEBUG -- : crawler 2 found 5\n" +
#    "[2019-11-17 16:32:03.608] DEBUG -- : data-processor 4 got 5\n" +
#    "[2019-11-17 16:32:03.609] DEBUG -- : crawler 0 found 6\n" +
#    "[2019-11-17 16:32:03.609] DEBUG -- : crawler 1 found 7\n" +
#    "[2019-11-17 16:32:03.609] DEBUG -- : data-processor 6 got 7\n" +
#    "[2019-11-17 16:32:03.610] DEBUG -- : crawler 3 found 8\n" +
#    "[2019-11-17 16:32:03.610] DEBUG -- : data-processor 5 got 6\n" +
#    "[2019-11-17 16:32:03.611] DEBUG -- : data-processor 7 got 8\n" +
#    "[2019-11-17 16:32:03.622] DEBUG -- : crawler 2 found 9\n" +
#    "[2019-11-17 16:32:03.622] DEBUG -- : crawler 0 found a\n" +
#    "[2019-11-17 16:32:03.623] DEBUG -- : crawler 1 found b\n" +
#    "[2019-11-17 16:32:03.624] DEBUG -- : crawler 3 found c\n" +
#    "[2019-11-17 16:32:03.624] DEBUG -- : data-processor 8 got 9\n" +
#    "[2019-11-17 16:32:03.625] DEBUG -- : data-processor 9 got a\n" +
#    "[2019-11-17 16:32:03.625] DEBUG -- : data-processor 10 got b\n" +
#    "[2019-11-17 16:32:03.625] DEBUG -- : data-processor 11 got c\n" +
#    "[2019-11-17 16:32:03.632] DEBUG -- : crawler 2 found d\n" +
#    "[2019-11-17 16:32:03.633] DEBUG -- : crawler 0 found e\n" +
#    "[2019-11-17 16:32:03.633] DEBUG -- : crawler 1 found f\n" +
#    "[2019-11-17 16:32:03.633] DEBUG -- : crawler 3 found 10\n" +
#    "[2019-11-17 16:32:03.643] DEBUG -- : crawler 3 found 11\n" +
#    "[2019-11-17 16:32:03.644] DEBUG -- : crawler 2 found 12\n" +
#    "[2019-11-17 16:32:03.645] DEBUG -- : crawler 0 found 13\n" +
#    "[2019-11-17 16:32:03.645] DEBUG -- : crawler 1 found 14\n" +
#    "[2019-11-17 16:32:03.654] DEBUG -- : crawler 2 found 15\n" +
#    "[2019-11-17 16:32:03.654] DEBUG -- : crawler 3 found 16\n" +
#    "[2019-11-17 16:32:03.655] DEBUG -- : crawler 0 found 17\n" +
#    "[2019-11-17 16:32:03.656] DEBUG -- : crawler 1 found 18\n" +
#    "[2019-11-17 16:32:03.664] DEBUG -- : crawler 2 found 19\n" +
#    "[2019-11-17 16:32:03.667] DEBUG -- : crawler 3 found 1a\n" +
#    "[2019-11-17 16:32:03.668] DEBUG -- : crawler 0 found 1b\n" +
#    "[2019-11-17 16:32:03.669] DEBUG -- : crawler 1 found 1c\n" +
#    "[2019-11-17 16:32:03.675] DEBUG -- : crawler 2 found 1d\n" +
#    "[2019-11-17 16:32:03.680] DEBUG -- : crawler 3 found 1e\n" +
#    "[2019-11-17 16:32:03.697] DEBUG -- : data-processor 12 got d\n" +
#    "[2019-11-17 16:32:03.698] DEBUG -- : data-processor 13 got e\n" +
#    "[2019-11-17 16:32:03.699] DEBUG -- : data-processor 14 got f\n" +
#    "[2019-11-17 16:32:03.699] DEBUG -- : data-processor 15 got 10\n" +
#    "[2019-11-17 16:32:03.710] DEBUG -- : data-processor 16 got 11\n" +
#    "[2019-11-17 16:32:03.710] DEBUG -- : data-processor 17 got 12\n" +
#    "[2019-11-17 16:32:03.714] DEBUG -- : data-processor 18 got 13\n" +
#    "[2019-11-17 16:32:03.714] DEBUG -- : data-processor 19 got 14\n" +
#    "[2019-11-17 16:32:03.723] DEBUG -- : data-processor 1 got 15\n" +
#    "[2019-11-17 16:32:03.724] DEBUG -- : crawler 0 found 1f\n" +
#    "[2019-11-17 16:32:03.724] DEBUG -- : crawler 1 found 20\n" +
#    "[2019-11-17 16:32:03.725] DEBUG -- : crawler 2 found 21\n" +
#    "[2019-11-17 16:32:03.725] DEBUG -- : crawler 3 found 22\n" +
#    "[2019-11-17 16:32:03.727] DEBUG -- : data-processor 0 got 16\n" +
#    "[2019-11-17 16:32:03.727] DEBUG -- : data-processor 2 got 17\n" +
#    "[2019-11-17 16:32:03.728] DEBUG -- : data-processor 3 got 18\n" +
#    "[2019-11-17 16:32:03.734] DEBUG -- : crawler 0 found 23\n" +
#    "[2019-11-17 16:32:03.734] DEBUG -- : crawler 1 found 24\n" +
#    "[2019-11-17 16:32:03.735] DEBUG -- : crawler 2 found 25\n" +
#    "[2019-11-17 16:32:03.736] DEBUG -- : crawler 3 found 26\n" +
#    "[2019-11-17 16:32:03.802] DEBUG -- : data-processor 6 got 19\n" +
#    "[2019-11-17 16:32:03.803] DEBUG -- : data-processor 4 got 1a\n" +
#    "[2019-11-17 16:32:03.803] DEBUG -- : data-processor 5 got 1b\n" +
#    "[2019-11-17 16:32:03.804] DEBUG -- : data-processor 7 got 1c\n" +
#    "[2019-11-17 16:32:03.816] DEBUG -- : data-processor 8 got 1d\n" +
#    "[2019-11-17 16:32:03.817] DEBUG -- : data-processor 9 got 1e\n" +
#    "[2019-11-17 16:32:03.817] DEBUG -- : data-processor 10 got 1f\n" +
#    "[2019-11-17 16:32:03.817] DEBUG -- : data-processor 11 got 20\n" +
#    "[2019-11-17 16:32:03.818] DEBUG -- : crawler 0 found 27\n" +
#    "[2019-11-17 16:32:03.818] DEBUG -- : crawler 1 found 28\n" +
#    "[2019-11-17 16:32:03.818] DEBUG -- : crawler 2 found 29\n" +
#    "[2019-11-17 16:32:03.819] DEBUG -- : crawler 3 found 2a\n" +
#    "[2019-11-17 16:32:03.828] DEBUG -- : data-processor 12 got 21\n" +
#    "[2019-11-17 16:32:03.829] DEBUG -- : crawler 1 found 2b\n" +
#    "[2019-11-17 16:32:03.829] DEBUG -- : crawler 2 found 2c\n" +
#    "[2019-11-17 16:32:03.830] DEBUG -- : crawler 3 found 2d\n" +
#    "[2019-11-17 16:32:03.830] DEBUG -- : crawler 0 found 2e\n" +
#    "[2019-11-17 16:32:03.831] DEBUG -- : data-processor 13 got 22\n" +
#    "[2019-11-17 16:32:03.832] DEBUG -- : data-processor 14 got 23\n" +
#    "[2019-11-17 16:32:03.832] DEBUG -- : data-processor 15 got 24\n" +
#    "[2019-11-17 16:32:03.907] DEBUG -- : data-processor 17 got 25\n" +
#    "[2019-11-17 16:32:03.908] DEBUG -- : data-processor 18 got 26\n" +
#    "[2019-11-17 16:32:03.908] DEBUG -- : crawler 1 found 2f\n" +
#    "[2019-11-17 16:32:03.909] DEBUG -- : crawler 2 found 30\n" +
#    "[2019-11-17 16:32:03.909] DEBUG -- : crawler 3 found 31\n" +
#    "[2019-11-17 16:32:03.910] DEBUG -- : crawler 0 found 32\n" +
#    "[2019-11-17 16:32:03.910] DEBUG -- : data-processor 16 got 27\n" +
#    "[2019-11-17 16:32:03.911] DEBUG -- : data-processor 19 got 28\n" +
#    "[2019-11-17 16:32:03.918] DEBUG -- : crawler 1 found 33\n" +
#    "[2019-11-17 16:32:03.919] DEBUG -- : crawler 2 found 34\n" +
#    "[2019-11-17 16:32:03.923] DEBUG -- : crawler 3 found 35\n" +
#    "[2019-11-17 16:32:03.923] DEBUG -- : crawler 0 found 36\n" +
#    "[2019-11-17 16:32:03.924] DEBUG -- : data-processor 1 got 29\n" +
#    "[2019-11-17 16:32:03.924] DEBUG -- : data-processor 0 got 2a\n" +
#    "[2019-11-17 16:32:03.924] DEBUG -- : data-processor 2 got 2b\n" +
#    "[2019-11-17 16:32:03.925] DEBUG -- : data-processor 3 got 2c\n" +
#    "[2019-11-17 16:32:03.933] DEBUG -- : data-processor 4 got 2d\n" +
#    "[2019-11-17 16:32:03.933] DEBUG -- : crawler 1 found 37\n" +
#    "[2019-11-17 16:32:03.934] DEBUG -- : crawler 2 found 38\n" +
#    "[2019-11-17 16:32:03.934] DEBUG -- : crawler 3 found 39\n" +
#    "[2019-11-17 16:32:03.935] DEBUG -- : crawler 0 found 3a\n" +
#    "[2019-11-17 16:32:03.935] DEBUG -- : data-processor 7 got 2e\n" +
#    "[2019-11-17 16:32:03.936] DEBUG -- : data-processor 6 got 2f\n" +
#    "[2019-11-17 16:32:03.936] DEBUG -- : data-processor 5 got 30\n" +
#    "[2019-11-17 16:32:03.946] DEBUG -- : crawler 1 found 3b\n" +
#    "[2019-11-17 16:32:03.947] DEBUG -- : crawler 2 found 3c\n" +
#    "[2019-11-17 16:32:03.947] DEBUG -- : crawler 3 found 3d\n" +
#    "[2019-11-17 16:32:03.948] DEBUG -- : crawler 0 found 3e\n" +
#    "[2019-11-17 16:32:03.981]  INFO -- : \n" +
#    "crawlers found: 15, 15, 16, 16\n" +
#    "data processors consumed: 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2\n" +
#    "[2019-11-17 16:32:04.010] DEBUG -- : data-processor 8 got 31\n" +
#    "[2019-11-17 16:32:04.011] DEBUG -- : data-processor 9 got 32\n" +
#    "[2019-11-17 16:32:04.012] DEBUG -- : data-processor 10 got 33\n" +
#    "[2019-11-17 16:32:04.012] DEBUG -- : data-processor 11 got 34\n" +
#    "[2019-11-17 16:32:04.030] DEBUG -- : data-processor 12 got 35\n" +
#    "[2019-11-17 16:32:04.031] DEBUG -- : data-processor 15 got 36\n" +
#    "[2019-11-17 16:32:04.031] DEBUG -- : data-processor 13 got 37\n" +
#    "[2019-11-17 16:32:04.032] DEBUG -- : data-processor 14 got 38\n" +
#    "[2019-11-17 16:32:04.032] DEBUG -- : crawler 1 found 3f\n" +
#    "[2019-11-17 16:32:04.032] DEBUG -- : crawler 2 found 40\n" +
#    "[2019-11-17 16:32:04.033] DEBUG -- : crawler 3 found 41\n" +
#    "[2019-11-17 16:32:04.033] DEBUG -- : crawler 0 found 42\n" +
#    "[2019-11-17 16:32:04.038] DEBUG -- : data-processor 17 got 39\n" +
#    "[2019-11-17 16:32:04.040] DEBUG -- : data-processor 16 got 3a\n" +
#    "[2019-11-17 16:32:04.041] DEBUG -- : data-processor 18 got 3b\n" +
#    "[2019-11-17 16:32:04.041] DEBUG -- : data-processor 19 got 3c\n" +
#    "[2019-11-17 16:32:04.043] DEBUG -- : crawler 1 found 43\n" +
#    "[2019-11-17 16:32:04.043] DEBUG -- : crawler 2 found 44\n" +
#    "[2019-11-17 16:32:04.044] DEBUG -- : crawler 0 found 45\n" +
#    "[2019-11-17 16:32:04.044] DEBUG -- : crawler 3 found 46\n" +
#    "[2019-11-17 16:32:04.118] DEBUG -- : data-processor 2 got 3d\n" +
#    "[2019-11-17 16:32:04.118] DEBUG -- : data-processor 3 got 3e\n" +
#    "[2019-11-17 16:32:04.119] DEBUG -- : data-processor 1 got 3f\n" +
#    "[2019-11-17 16:32:04.120] DEBUG -- : data-processor 0 got 40\n" +
#    "[2019-11-17 16:32:04.120] DEBUG -- : crawler 1 found 47\n" +
#    "[2019-11-17 16:32:04.121] DEBUG -- : crawler 2 found 48\n" +
#    "[2019-11-17 16:32:04.122] DEBUG -- : crawler 0 found 49\n" +
#    "[2019-11-17 16:32:04.123] DEBUG -- : crawler 3 found 4a\n" +
#    "[2019-11-17 16:32:04.129] DEBUG -- : crawler 1 found 4b\n" +
#    "[2019-11-17 16:32:04.130] DEBUG -- : crawler 2 found 4c\n" +
#    "[2019-11-17 16:32:04.131] DEBUG -- : crawler 3 found 4d\n" +
#    "[2019-11-17 16:32:04.131] DEBUG -- : crawler 0 found 4e\n" +
#    "[2019-11-17 16:32:04.134] DEBUG -- : data-processor 4 got 41\n" +
#    "[2019-11-17 16:32:04.135] DEBUG -- : data-processor 6 got 42\n" +
#    "[2019-11-17 16:32:04.135] DEBUG -- : data-processor 7 got 43\n" +
#    "[2019-11-17 16:32:04.136] DEBUG -- : data-processor 5 got 44\n" +
#    "[2019-11-17 16:32:04.143] DEBUG -- : data-processor 9 got 45\n" +
#    "[2019-11-17 16:32:04.143] DEBUG -- : crawler 3 found 52\n" +
#    "[2019-11-17 16:32:04.145] DEBUG -- : crawler 1 found 4f\n" +
#    "[2019-11-17 16:32:04.145] DEBUG -- : crawler 0 found 50\n" +
#    "[2019-11-17 16:32:04.145] DEBUG -- : crawler 2 found 51\n" +
#    "[2019-11-17 16:32:04.146] DEBUG -- : data-processor 11 got 46\n" +
#    "[2019-11-17 16:32:04.146] DEBUG -- : data-processor 8 got 47\n" +
#    "[2019-11-17 16:32:04.147] DEBUG -- : data-processor 10 got 48\n" +
#    "[2019-11-17 16:32:04.155] DEBUG -- : crawler 3 found 53\n" +
#    "[2019-11-17 16:32:04.156] DEBUG -- : crawler 1 found 54\n" +
#    "[2019-11-17 16:32:04.156] DEBUG -- : crawler 0 found 55\n" +
#    "[2019-11-17 16:32:04.157] DEBUG -- : crawler 2 found 56\n" +
#    "[2019-11-17 16:32:04.221] DEBUG -- : data-processor 13 got 49\n" +
#    "[2019-11-17 16:32:04.221] DEBUG -- : data-processor 12 got 4a\n" +
#    "[2019-11-17 16:32:04.222] DEBUG -- : data-processor 15 got 4b\n" +
#    "[2019-11-17 16:32:04.223] DEBUG -- : data-processor 14 got 4c\n" +
#    "[2019-11-17 16:32:04.245] DEBUG -- : data-processor 17 got 4d\n" +
#    "[2019-11-17 16:32:04.245] DEBUG -- : data-processor 18 got 4e\n" +
#    "[2019-11-17 16:32:04.245] DEBUG -- : data-processor 16 got 4f\n" +
#    "[2019-11-17 16:32:04.246] DEBUG -- : data-processor 19 got 50\n" +
#    "[2019-11-17 16:32:04.246] DEBUG -- : crawler 3 found 57\n" +
#    "[2019-11-17 16:32:04.247] DEBUG -- : crawler 1 found 58\n" +
#    "[2019-11-17 16:32:04.247] DEBUG -- : crawler 0 found 59\n" +
#    "[2019-11-17 16:32:04.248] DEBUG -- : crawler 2 found 5a\n" +
#    "[2019-11-17 16:32:04.248] DEBUG -- : data-processor 1 got 51\n" +
#    "[2019-11-17 16:32:04.248] DEBUG -- : data-processor 0 got 52\n" +
#    "[2019-11-17 16:32:04.249] DEBUG -- : data-processor 2 got 53\n" +
#    "[2019-11-17 16:32:04.249] DEBUG -- : data-processor 3 got 54\n" +
#    "[2019-11-17 16:32:04.258] DEBUG -- : crawler 3 found 5b\n" +
#    "[2019-11-17 16:32:04.259] DEBUG -- : crawler 1 found 5c\n" +
#    "[2019-11-17 16:32:04.259] DEBUG -- : crawler 0 found 5d\n" +
#    "[2019-11-17 16:32:04.260] DEBUG -- : crawler 2 found 5e\n" +
#    "[2019-11-17 16:32:04.323] DEBUG -- : data-processor 7 got 55\n" +
#    "[2019-11-17 16:32:04.324] DEBUG -- : data-processor 5 got 56\n" +
#    "[2019-11-17 16:32:04.324] DEBUG -- : data-processor 4 got 57\n" +
#    "[2019-11-17 16:32:04.325] DEBUG -- : crawler 3 found 5f\n" +
#    "[2019-11-17 16:32:04.325] DEBUG -- : crawler 0 found 60\n" +
#    "[2019-11-17 16:32:04.326] DEBUG -- : crawler 1 found 61\n" +
#    "[2019-11-17 16:32:04.326] DEBUG -- : crawler 2 found 62\n" +
#    "[2019-11-17 16:32:04.327] DEBUG -- : data-processor 6 got 58\n" +
#    "[2019-11-17 16:32:04.336] DEBUG -- : crawler 3 found 63\n" +
#    "[2019-11-17 16:32:04.337] DEBUG -- : crawler 0 found 64\n" +
#    "[2019-11-17 16:32:04.338] DEBUG -- : crawler 1 found 65\n" +
#    "[2019-11-17 16:32:04.338] DEBUG -- : crawler 2 found 66\n" +
#    "[2019-11-17 16:32:04.348] DEBUG -- : data-processor 9 got 59\n" +
#    "[2019-11-17 16:32:04.349] DEBUG -- : data-processor 11 got 5a\n" +
#    "[2019-11-17 16:32:04.351] DEBUG -- : data-processor 8 got 5b\n" +
#    "[2019-11-17 16:32:04.352] DEBUG -- : data-processor 10 got 5c\n" +
#    "[2019-11-17 16:32:04.352] DEBUG -- : data-processor 13 got 5d\n" +
#    "[2019-11-17 16:32:04.352] DEBUG -- : data-processor 12 got 5e\n" +
#    "[2019-11-17 16:32:04.353] DEBUG -- : data-processor 15 got 5f\n" +
#    "[2019-11-17 16:32:04.354] DEBUG -- : data-processor 14 got 60\n" +
#    "[2019-11-17 16:32:04.354] DEBUG -- : crawler 2 found 67\n" +
#    "[2019-11-17 16:32:04.355] DEBUG -- : crawler 1 found 68\n" +
#    "[2019-11-17 16:32:04.355] DEBUG -- : crawler 3 found 69\n" +
#    "[2019-11-17 16:32:04.356] DEBUG -- : crawler 0 found 6a\n" +
#    "[2019-11-17 16:32:04.365] DEBUG -- : crawler 2 found 6b\n" +
#    "[2019-11-17 16:32:04.366] DEBUG -- : crawler 1 found 6c\n" +
#    "[2019-11-17 16:32:04.366] DEBUG -- : crawler 0 found 6d\n" +
#    "[2019-11-17 16:32:04.367] DEBUG -- : crawler 3 found 6e\n" +
#    "[2019-11-17 16:32:04.386]  INFO -- : \n" +
#    "crawlers found: 27, 27, 28, 28\n" +
#    "data processors consumed: 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4\n" +
#    "[2019-11-17 16:32:04.427] DEBUG -- : data-processor 18 got 61\n" +
#    "[2019-11-17 16:32:04.428] DEBUG -- : data-processor 16 got 62\n" +
#    "[2019-11-17 16:32:04.429] DEBUG -- : data-processor 17 got 63\n" +
#    "[2019-11-17 16:32:04.431] DEBUG -- : data-processor 19 got 64\n" +
#    "[2019-11-17 16:32:04.457] DEBUG -- : data-processor 1 got 65\n" +
#    "[2019-11-17 16:32:04.458] DEBUG -- : data-processor 0 got 66\n" +
#    "[2019-11-17 16:32:04.458] DEBUG -- : data-processor 2 got 67\n" +
#    "[2019-11-17 16:32:04.460] DEBUG -- : data-processor 3 got 68\n" +
#    "[2019-11-17 16:32:04.460] DEBUG -- : crawler 1 found 6f\n" +
#    "[2019-11-17 16:32:04.460] DEBUG -- : crawler 2 found 70\n" +
#    "[2019-11-17 16:32:04.461] DEBUG -- : crawler 0 found 71\n" +
#    "[2019-11-17 16:32:04.462] DEBUG -- : crawler 3 found 72\n" +
#    "[2019-11-17 16:32:04.462] DEBUG -- : data-processor 4 got 69\n" +
#    "[2019-11-17 16:32:04.463] DEBUG -- : data-processor 5 got 6a\n" +
#    "[2019-11-17 16:32:04.463] DEBUG -- : data-processor 7 got 6b\n" +
#    "[2019-11-17 16:32:04.463] DEBUG -- : data-processor 6 got 6c\n" +
#    "[2019-11-17 16:32:04.469] DEBUG -- : crawler 1 found 73\n" +
#    "[2019-11-17 16:32:04.470] DEBUG -- : crawler 2 found 74\n" +
#    "[2019-11-17 16:32:04.471] DEBUG -- : crawler 0 found 75\n" +
#    "[2019-11-17 16:32:04.472] DEBUG -- : crawler 3 found 76\n" +
#    "[2019-11-17 16:32:04.535] DEBUG -- : data-processor 10 got 6d\n" +
#    "[2019-11-17 16:32:04.535] DEBUG -- : data-processor 9 got 6e\n" +
#    "[2019-11-17 16:32:04.539] DEBUG -- : data-processor 12 got 6f\n" +
#    "[2019-11-17 16:32:04.540] DEBUG -- : crawler 3 found 77\n" +
#    "[2019-11-17 16:32:04.540] DEBUG -- : data-processor 13 got 70\n" +
#    "[2019-11-17 16:32:04.540] DEBUG -- : crawler 2 found 78\n" +
#    "[2019-11-17 16:32:04.541] DEBUG -- : crawler 1 found 79\n" +
#    "[2019-11-17 16:32:04.541] DEBUG -- : crawler 0 found 7a\n" +
#    "[2019-11-17 16:32:04.545] DEBUG -- : crawler 3 found 7b\n" +
#    "[2019-11-17 16:32:04.546] DEBUG -- : crawler 2 found 7c\n" +
#    "[2019-11-17 16:32:04.547] DEBUG -- : crawler 1 found 7d\n" +
#    "[2019-11-17 16:32:04.547] DEBUG -- : crawler 0 found 7e\n" +
#    "[2019-11-17 16:32:04.561] DEBUG -- : data-processor 14 got 71\n" +
#    "[2019-11-17 16:32:04.562] DEBUG -- : data-processor 15 got 72\n" +
#    "[2019-11-17 16:32:04.563] DEBUG -- : data-processor 11 got 73\n" +
#    "[2019-11-17 16:32:04.563] DEBUG -- : data-processor 8 got 74\n" +
#    "[2019-11-17 16:32:04.564] DEBUG -- : data-processor 18 got 75\n" +
#    "[2019-11-17 16:32:04.564] DEBUG -- : data-processor 19 got 76\n" +
#    "[2019-11-17 16:32:04.564] DEBUG -- : data-processor 16 got 77\n" +
#    "[2019-11-17 16:32:04.565] DEBUG -- : data-processor 17 got 78\n" +
#    "[2019-11-17 16:32:04.565] DEBUG -- : crawler 3 found 7f\n" +
#    "[2019-11-17 16:32:04.565] DEBUG -- : crawler 2 found 80\n" +
#    "[2019-11-17 16:32:04.566] DEBUG -- : crawler 1 found 81\n" +
#    "[2019-11-17 16:32:04.566] DEBUG -- : crawler 0 found 82\n" +
#    "[2019-11-17 16:32:04.575] DEBUG -- : crawler 3 found 83\n" +
#    "[2019-11-17 16:32:04.640] DEBUG -- : data-processor 5 got 79\n" +
#    "[2019-11-17 16:32:04.641] DEBUG -- : data-processor 1 got 7a\n" +
#    "[2019-11-17 16:32:04.642] DEBUG -- : data-processor 3 got 7b\n" +
#    "[2019-11-17 16:32:04.642] DEBUG -- : data-processor 0 got 7c\n" +
#    "[2019-11-17 16:32:04.642] DEBUG -- : crawler 2 found 84\n" +
#    "[2019-11-17 16:32:04.643] DEBUG -- : crawler 1 found 85\n" +
#    "[2019-11-17 16:32:04.643] DEBUG -- : crawler 0 found 86\n" +
#    "[2019-11-17 16:32:04.644] DEBUG -- : crawler 3 found 87\n" +
#    "[2019-11-17 16:32:04.653] DEBUG -- : crawler 2 found 88\n" +
#    "[2019-11-17 16:32:04.654] DEBUG -- : crawler 1 found 89\n" +
#    "[2019-11-17 16:32:04.654] DEBUG -- : crawler 0 found 8a\n" +
#    "[2019-11-17 16:32:04.654] DEBUG -- : crawler 3 found 8b\n" +
#    "[2019-11-17 16:32:04.666] DEBUG -- : data-processor 4 got 7d\n" +
#    "[2019-11-17 16:32:04.667] DEBUG -- : data-processor 6 got 7e\n" +
#    "[2019-11-17 16:32:04.669] DEBUG -- : data-processor 2 got 7f\n" +
#    "[2019-11-17 16:32:04.669] DEBUG -- : data-processor 7 got 80\n" +
#    "[2019-11-17 16:32:04.670] DEBUG -- : data-processor 10 got 81\n" +
#    "[2019-11-17 16:32:04.670] DEBUG -- : crawler 1 found 8c\n" +
#    "[2019-11-17 16:32:04.671] DEBUG -- : crawler 2 found 8d\n" +
#    "[2019-11-17 16:32:04.671] DEBUG -- : crawler 3 found 8e\n" +
#    "[2019-11-17 16:32:04.671] DEBUG -- : data-processor 12 got 84\n" +
#    "[2019-11-17 16:32:04.672] DEBUG -- : data-processor 14 got 85\n" +
#    "[2019-11-17 16:32:04.672] DEBUG -- : data-processor 11 got 86\n" +
#    "[2019-11-17 16:32:04.672] DEBUG -- : crawler 0 found 8f\n" +
#    "[2019-11-17 16:32:04.678] DEBUG -- : crawler 1 found 90\n" +
#    "[2019-11-17 16:32:04.678] DEBUG -- : crawler 2 found 91\n" +
#    "[2019-11-17 16:32:04.680] DEBUG -- : crawler 3 found 92\n" +
#    "[2019-11-17 16:32:04.681] DEBUG -- : crawler 0 found 93\n" +
#    "[2019-11-17 16:32:04.688] DEBUG -- : crawler 1 found 94\n" +
#    "[2019-11-17 16:32:04.738] DEBUG -- : data-processor 15 got 87\n" +
#    "[2019-11-17 16:32:04.743] DEBUG -- : data-processor 18 got 88\n" +
#    "[2019-11-17 16:32:04.743] DEBUG -- : data-processor 8 got 89\n" +
#    "[2019-11-17 16:32:04.744] DEBUG -- : data-processor 16 got 8a\n" +
#    "[2019-11-17 16:32:04.772] DEBUG -- : data-processor 9 got 82\n" +
#    "[2019-11-17 16:32:04.772] DEBUG -- : data-processor 13 got 83\n" +
#    "[2019-11-17 16:32:04.773] DEBUG -- : data-processor 17 got 8b\n" +
#    "[2019-11-17 16:32:04.773] DEBUG -- : data-processor 19 got 8c\n" +
#    "[2019-11-17 16:32:04.774] DEBUG -- : data-processor 5 got 8d\n" +
#    "[2019-11-17 16:32:04.774] DEBUG -- : data-processor 0 got 8e\n" +
#    "[2019-11-17 16:32:04.774] DEBUG -- : data-processor 1 got 8f\n" +
#    "[2019-11-17 16:32:04.775] DEBUG -- : data-processor 3 got 90\n" +
#    "[2019-11-17 16:32:04.775] DEBUG -- : crawler 2 found 95\n" +
#    "[2019-11-17 16:32:04.776] DEBUG -- : crawler 3 found 96\n" +
#    "[2019-11-17 16:32:04.778] DEBUG -- : crawler 0 found 97\n" +
#    "[2019-11-17 16:32:04.778] DEBUG -- : crawler 1 found 98\n" +
#    "[2019-11-17 16:32:04.785] DEBUG -- : crawler 2 found 99\n" +
#    "[2019-11-17 16:32:04.785] DEBUG -- : crawler 0 found 9a\n" +
#    "[2019-11-17 16:32:04.786]  INFO -- : \n" +
#    "crawlers found: 38, 38, 39, 39\n" +
#    "data processors consumed: 8, 8, 7, 8, 7, 8, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7\n" +
#    "[2019-11-17 16:32:04.841] DEBUG -- : data-processor 7 got 91\n" +
#    "[2019-11-17 16:32:04.841] DEBUG -- : crawler 3 found 9b\n" +
#    "[2019-11-17 16:32:04.842] DEBUG -- : crawler 1 found 9c\n" +
#    "[2019-11-17 16:32:04.842] DEBUG -- : crawler 2 found 9d\n" +
#    "[2019-11-17 16:32:04.843] DEBUG -- : crawler 0 found 9e\n" +
#    "[2019-11-17 16:32:04.843] DEBUG -- : data-processor 10 got 92\n" +
#    "[2019-11-17 16:32:04.844] DEBUG -- : data-processor 4 got 93\n" +
#    "[2019-11-17 16:32:04.844] DEBUG -- : data-processor 12 got 94\n" +
#    "[2019-11-17 16:32:04.853] DEBUG -- : crawler 3 found 9f\n" +
#    "[2019-11-17 16:32:04.854] DEBUG -- : crawler 1 found a0\n" +
#    "[2019-11-17 16:32:04.854] DEBUG -- : crawler 2 found a1\n" +
#    "[2019-11-17 16:32:04.855] DEBUG -- : crawler 0 found a2\n" +
#    "[2019-11-17 16:32:04.876] DEBUG -- : data-processor 14 got 95\n" +
#    "[2019-11-17 16:32:04.877] DEBUG -- : data-processor 6 got 96\n" +
#    "[2019-11-17 16:32:04.878] DEBUG -- : data-processor 2 got 97\n" +
#    "[2019-11-17 16:32:04.878] DEBUG -- : data-processor 11 got 98\n" +
#    "[2019-11-17 16:32:04.879] DEBUG -- : data-processor 15 got 99\n" +
#    "[2019-11-17 16:32:04.879] DEBUG -- : data-processor 16 got 9a\n" +
#    "[2019-11-17 16:32:04.879] DEBUG -- : data-processor 18 got 9b\n" +
#    "[2019-11-17 16:32:04.880] DEBUG -- : data-processor 8 got 9c\n" +
#    "[2019-11-17 16:32:04.880] DEBUG -- : crawler 3 found a3\n" +
#    "[2019-11-17 16:32:04.881] DEBUG -- : crawler 1 found a4\n" +
#    "[2019-11-17 16:32:04.881] DEBUG -- : crawler 2 found a5\n" +
#    "[2019-11-17 16:32:04.881] DEBUG -- : crawler 0 found a6\n" +
#    "[2019-11-17 16:32:04.947] DEBUG -- : data-processor 13 got 9d\n" +
#    "[2019-11-17 16:32:04.947] DEBUG -- : data-processor 0 got 9e\n" +
#    "[2019-11-17 16:32:04.948] DEBUG -- : data-processor 1 got 9f\n" +
#    "[2019-11-17 16:32:04.948] DEBUG -- : data-processor 19 got a0\n" +
#    "[2019-11-17 16:32:04.948] DEBUG -- : crawler 3 found a7\n" +
#    "[2019-11-17 16:32:04.949] DEBUG -- : crawler 1 found a8\n" +
#    "[2019-11-17 16:32:04.949] DEBUG -- : crawler 2 found a9\n" +
#    "[2019-11-17 16:32:04.949] DEBUG -- : crawler 0 found aa\n" +
#    "[2019-11-17 16:32:04.959] DEBUG -- : crawler 3 found ab\n" +
#    "[2019-11-17 16:32:04.960] DEBUG -- : crawler 1 found ac\n" +
#    "[2019-11-17 16:32:04.961] DEBUG -- : crawler 2 found ad\n" +
#    "[2019-11-17 16:32:04.961] DEBUG -- : crawler 0 found ae\n" +
#    "[2019-11-17 16:32:04.980] DEBUG -- : data-processor 3 got a1\n" +
#    "[2019-11-17 16:32:04.982] DEBUG -- : data-processor 9 got a2\n" +
#    "[2019-11-17 16:32:04.983] DEBUG -- : data-processor 17 got a3\n" +
#    "[2019-11-17 16:32:04.983] DEBUG -- : data-processor 5 got a4\n" +
#    "[2019-11-17 16:32:04.984] DEBUG -- : data-processor 10 got a5\n" +
#    "[2019-11-17 16:32:04.984] DEBUG -- : data-processor 4 got a6\n" +
#    "[2019-11-17 16:32:04.985] DEBUG -- : data-processor 12 got a7\n" +
#    "[2019-11-17 16:32:04.985] DEBUG -- : data-processor 7 got a8\n" +
#    "[2019-11-17 16:32:04.985] DEBUG -- : crawler 3 found af\n" +
#    "[2019-11-17 16:32:04.986] DEBUG -- : crawler 1 found b0\n" +
#    "[2019-11-17 16:32:04.986] DEBUG -- : crawler 2 found b1\n" +
#    "[2019-11-17 16:32:04.986] DEBUG -- : crawler 0 found b2\n" +
#    "[2019-11-17 16:32:04.996] DEBUG -- : crawler 3 found b3\n" +
#    "[2019-11-17 16:32:04.997] DEBUG -- : crawler 1 found b4\n" +
#    "[2019-11-17 16:32:05.053] DEBUG -- : data-processor 14 got a9\n" +
#    "[2019-11-17 16:32:05.054] DEBUG -- : data-processor 6 got aa\n" +
#    "[2019-11-17 16:32:05.054] DEBUG -- : data-processor 11 got ab\n" +
#    "[2019-11-17 16:32:05.055] DEBUG -- : data-processor 18 got ac\n" +
#    "[2019-11-17 16:32:05.055] DEBUG -- : crawler 2 found b5\n" +
#    "[2019-11-17 16:32:05.056] DEBUG -- : crawler 0 found b6\n" +
#    "[2019-11-17 16:32:05.056] DEBUG -- : crawler 1 found b7\n" +
#    "[2019-11-17 16:32:05.056] DEBUG -- : crawler 3 found b8\n" +
#    "[2019-11-17 16:32:05.064] DEBUG -- : crawler 2 found b9\n" +
#    "[2019-11-17 16:32:05.065] DEBUG -- : crawler 0 found ba\n" +
#    "[2019-11-17 16:32:05.065] DEBUG -- : crawler 1 found bb\n" +
#    "[2019-11-17 16:32:05.085] DEBUG -- : data-processor 8 got ad\n" +
#    "[2019-11-17 16:32:05.087] DEBUG -- : data-processor 2 got ae\n" +
#    "[2019-11-17 16:32:05.087] DEBUG -- : data-processor 15 got af\n" +
#    "[2019-11-17 16:32:05.087] DEBUG -- : data-processor 16 got b0\n" +
#    "[2019-11-17 16:32:05.088] DEBUG -- : data-processor 13 got b1\n" +
#    "[2019-11-17 16:32:05.088] DEBUG -- : data-processor 0 got b2\n" +
#    "[2019-11-17 16:32:05.088] DEBUG -- : data-processor 1 got b3\n" +
#    "[2019-11-17 16:32:05.089] DEBUG -- : data-processor 19 got b4\n" +
#    "[2019-11-17 16:32:05.089] DEBUG -- : crawler 3 found bc\n" +
#    "[2019-11-17 16:32:05.089] DEBUG -- : crawler 2 found bd\n" +
#    "[2019-11-17 16:32:05.090] DEBUG -- : crawler 0 found be\n" +
#    "[2019-11-17 16:32:05.090] DEBUG -- : crawler 1 found bf\n" +
#    "[2019-11-17 16:32:05.097] DEBUG -- : crawler 3 found c0\n" +
#    "[2019-11-17 16:32:05.157] DEBUG -- : data-processor 3 got b5\n" +
#    "[2019-11-17 16:32:05.157] DEBUG -- : data-processor 9 got b6\n" +
#    "[2019-11-17 16:32:05.157] DEBUG -- : data-processor 17 got b7\n" +
#    "[2019-11-17 16:32:05.158] DEBUG -- : data-processor 12 got b8\n" +
#    "[2019-11-17 16:32:05.158] DEBUG -- : crawler 2 found c1\n" +
#    "[2019-11-17 16:32:05.158] DEBUG -- : crawler 0 found c2\n" +
#    "[2019-11-17 16:32:05.159] DEBUG -- : crawler 1 found c3\n" +
#    "[2019-11-17 16:32:05.159] DEBUG -- : crawler 3 found c4\n" +
#    "[2019-11-17 16:32:05.167] DEBUG -- : crawler 0 found c5\n" +
#    "[2019-11-17 16:32:05.167] DEBUG -- : crawler 3 found c6\n" +
#    "[2019-11-17 16:32:05.190] DEBUG -- : data-processor 7 got b9\n" +
#    "[2019-11-17 16:32:05.191] DEBUG -- : data-processor 10 got ba\n" +
#    "[2019-11-17 16:32:05.192] DEBUG -- : data-processor 5 got bb\n" +
#    "[2019-11-17 16:32:05.193] DEBUG -- : data-processor 4 got bc\n" +
#    "[2019-11-17 16:32:05.193] DEBUG -- : data-processor 11 got bd\n" +
#    "[2019-11-17 16:32:05.194] DEBUG -- : crawler 2 found c7\n" +
#    "[2019-11-17 16:32:05.194] DEBUG -- : crawler 1 found c8\n" +
#    "[2019-11-17 16:32:05.194] DEBUG -- : crawler 0 found c9\n" +
#    "[2019-11-17 16:32:05.195] DEBUG -- : crawler 3 found ca\n" +
#    "[2019-11-17 16:32:05.195] DEBUG -- : data-processor 14 got be\n" +
#    "[2019-11-17 16:32:05.196] DEBUG -- : data-processor 6 got bf\n" +
#    "[2019-11-17 16:32:05.196] DEBUG -- : data-processor 18 got c0\n" +
#    "[2019-11-17 16:32:05.196]  INFO -- : \n" +
#    "crawlers found: 50, 50, 50, 52\n" +
#    "data processors consumed: 10, 10, 9, 10, 10, 10, 10, 10, 9, 9, 10, 10, 10, 9, 10, 9, 9, 9, 10, 9\n" +
#    "[2019-11-17 16:32:05.201] DEBUG -- : crawler 2 found cb\n" +
#    "[2019-11-17 16:32:05.201] DEBUG -- : crawler 1 found cc\n" +
#    "[2019-11-17 16:32:05.262] DEBUG -- : data-processor 15 got c1\n" +
#    "[2019-11-17 16:32:05.263] DEBUG -- : data-processor 13 got c2\n" +
#    "[2019-11-17 16:32:05.264] DEBUG -- : data-processor 8 got c3\n" +
#    "[2019-11-17 16:32:05.264] DEBUG -- : data-processor 2 got c4\n" +
#    "[2019-11-17 16:32:05.265] DEBUG -- : crawler 0 found cd\n" +
#    "[2019-11-17 16:32:05.265] DEBUG -- : crawler 3 found ce\n" +
#    "[2019-11-17 16:32:05.266] DEBUG -- : crawler 2 found cf\n" +
#    "[2019-11-17 16:32:05.266] DEBUG -- : crawler 1 found d0\n" +
#    "[2019-11-17 16:32:05.275] DEBUG -- : crawler 0 found d1\n" +
#    "[2019-11-17 16:32:05.275] DEBUG -- : crawler 3 found d2\n" +
#    "[2019-11-17 16:32:05.293] DEBUG -- : data-processor 16 got c5\n" +
#    "[2019-11-17 16:32:05.293] DEBUG -- : data-processor 0 got c6\n" +
#    "[2019-11-17 16:32:05.293] DEBUG -- : data-processor 1 got c7\n" +
#    "[2019-11-17 16:32:05.294] DEBUG -- : data-processor 19 got c8\n" +
#    "[2019-11-17 16:32:05.294] DEBUG -- : data-processor 3 got c9\n" +
#    "[2019-11-17 16:32:05.294] DEBUG -- : data-processor 9 got ca\n" +
#    "[2019-11-17 16:32:05.295] DEBUG -- : data-processor 17 got cb\n" +
#    "[2019-11-17 16:32:05.295] DEBUG -- : data-processor 12 got cc\n" +
#    "[2019-11-17 16:32:05.295] DEBUG -- : crawler 2 found d3\n" +
#    "[2019-11-17 16:32:05.296] DEBUG -- : crawler 1 found d4\n" +
#    "[2019-11-17 16:32:05.296] DEBUG -- : crawler 0 found d5\n" +
#    "[2019-11-17 16:32:05.296] DEBUG -- : crawler 3 found d6\n" +
#    "[2019-11-17 16:32:05.305] DEBUG -- : crawler 2 found d7\n" +
#    "[2019-11-17 16:32:05.367] DEBUG -- : data-processor 5 got cd\n" +
#    "[2019-11-17 16:32:05.368] DEBUG -- : data-processor 7 got ce\n" +
#    "[2019-11-17 16:32:05.368] DEBUG -- : data-processor 10 got cf\n" +
#    "[2019-11-17 16:32:05.368] DEBUG -- : data-processor 4 got d0\n" +
#    "[2019-11-17 16:32:05.369] DEBUG -- : crawler 3 found d8\n" +
#    "[2019-11-17 16:32:05.369] DEBUG -- : crawler 1 found d9\n" +
#    "[2019-11-17 16:32:05.369] DEBUG -- : crawler 0 found da\n" +
#    "[2019-11-17 16:32:05.370] DEBUG -- : crawler 2 found db\n" +
#    "[2019-11-17 16:32:05.377] DEBUG -- : crawler 3 found dc\n" +
#    "[2019-11-17 16:32:05.378] DEBUG -- : crawler 1 found dd\n" +
#    "[2019-11-17 16:32:05.379] DEBUG -- : crawler 2 found de\n" +
#    "[2019-11-17 16:32:05.392] DEBUG -- : data-processor 11 got d1\n" +
#    "[2019-11-17 16:32:05.393] DEBUG -- : data-processor 14 got d2\n" +
#    "[2019-11-17 16:32:05.399] DEBUG -- : data-processor 6 got d3\n" +
#    "[2019-11-17 16:32:05.400] DEBUG -- : data-processor 18 got d4\n" +
#    "[2019-11-17 16:32:05.400] DEBUG -- : data-processor 2 got d5\n" +
#    "[2019-11-17 16:32:05.401] DEBUG -- : data-processor 15 got d6\n" +
#    "[2019-11-17 16:32:05.401] DEBUG -- : data-processor 13 got d7\n" +
#    "[2019-11-17 16:32:05.402] DEBUG -- : data-processor 8 got d8\n" +
#    "[2019-11-17 16:32:05.402] DEBUG -- : crawler 0 found df\n" +
#    "[2019-11-17 16:32:05.402] DEBUG -- : crawler 3 found e0\n" +
#    "[2019-11-17 16:32:05.403] DEBUG -- : crawler 1 found e1\n" +
#    "[2019-11-17 16:32:05.403] DEBUG -- : crawler 2 found e2\n" +
#    "[2019-11-17 16:32:05.410] DEBUG -- : crawler 0 found e3\n" +
#    "[2019-11-17 16:32:05.411] DEBUG -- : crawler 3 found e4\n" +
#    "[2019-11-17 16:32:05.466] DEBUG -- : data-processor 0 got d9\n" +
#    "[2019-11-17 16:32:05.467] DEBUG -- : data-processor 16 got da\n" +
#    "[2019-11-17 16:32:05.473] DEBUG -- : data-processor 1 got db\n" +
#    "[2019-11-17 16:32:05.473] DEBUG -- : data-processor 19 got dc\n" +
#    "[2019-11-17 16:32:05.474] DEBUG -- : crawler 1 found e5\n" +
#    "[2019-11-17 16:32:05.474] DEBUG -- : crawler 2 found e6\n" +
#    "[2019-11-17 16:32:05.475] DEBUG -- : crawler 0 found e7\n" +
#    "[2019-11-17 16:32:05.475] DEBUG -- : crawler 3 found e8\n" +
#    "[2019-11-17 16:32:05.486] DEBUG -- : crawler 1 found e9\n" +
#    "[2019-11-17 16:32:05.487] DEBUG -- : crawler 2 found ea\n" +
#    "[2019-11-17 16:32:05.487] DEBUG -- : crawler 0 found eb\n" +
#    "[2019-11-17 16:32:05.488] DEBUG -- : crawler 3 found ec\n" +
#    "[2019-11-17 16:32:05.495] DEBUG -- : data-processor 12 got dd\n" +
#    "[2019-11-17 16:32:05.495] DEBUG -- : data-processor 3 got de\n" +
#    "[2019-11-17 16:32:05.501] DEBUG -- : data-processor 9 got df\n" +
#    "[2019-11-17 16:32:05.502] DEBUG -- : data-processor 17 got e0\n" +
#    "[2019-11-17 16:32:05.505] DEBUG -- : data-processor 5 got e1\n" +
#    "[2019-11-17 16:32:05.506] DEBUG -- : data-processor 7 got e2\n" +
#    "[2019-11-17 16:32:05.506] DEBUG -- : data-processor 10 got e3\n" +
#    "[2019-11-17 16:32:05.506] DEBUG -- : data-processor 4 got e4\n" +
#    "[2019-11-17 16:32:05.507] DEBUG -- : crawler 1 found ed\n" +
#    "[2019-11-17 16:32:05.507] DEBUG -- : crawler 0 found ee\n" +
#    "[2019-11-17 16:32:05.508] DEBUG -- : crawler 2 found ef\n" +
#    "[2019-11-17 16:32:05.508] DEBUG -- : crawler 3 found f0\n" +
#    "[2019-11-17 16:32:05.516] DEBUG -- : crawler 0 found f1\n" +
#    "[2019-11-17 16:32:05.517] DEBUG -- : crawler 2 found f2\n" +
#    "[2019-11-17 16:32:05.571] DEBUG -- : data-processor 11 got e5\n" +
#    "[2019-11-17 16:32:05.572] DEBUG -- : data-processor 14 got e6\n" +
#    "[2019-11-17 16:32:05.576] DEBUG -- : data-processor 6 got e7\n" +
#    "[2019-11-17 16:32:05.576] DEBUG -- : data-processor 18 got e8\n" +
#    "[2019-11-17 16:32:05.583]  INFO -- : \n" +
#    "crawlers found: 60, 59, 61, 62\n" +
#    "data processors consumed: 12, 12, 11, 12, 12, 12, 12, 12, 11, 11, 12, 12, 12, 11, 12, 11, 11, 11, 12, 11\n" +
#    "[2019-11-17 16:32:05.618] DEBUG -- : crawler 1 found f3\n" +
#    "[2019-11-17 16:32:05.619] DEBUG -- : crawler 3 found f4\n" +
#    "[2019-11-17 16:32:05.633] DEBUG -- : crawler 0 found f5\n" +
#    "[2019-11-17 16:32:05.633] DEBUG -- : crawler 2 found f6\n"




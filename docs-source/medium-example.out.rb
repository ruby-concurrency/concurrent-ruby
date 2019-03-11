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
# => "[2019-03-10 20:08:26.229] FATAL -- : :tornado\n" +
#    "[2019-03-10 20:08:26.231]  INFO -- : :breeze\n"

# the logging could be wrapped in a method
def log(severity, message)
  LOGGING.tell Log[severity, message]
  true
end                                      # => :log

include Logger::Severity                 # => Object
log INFO, 'alive'                        # => true
sleep 0.05                               # => 0
get_captured_output
# => "[2019-03-10 20:08:26.281]  INFO -- : alive\n"


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
# => {"2"=>18,
#     "1"=>18,
#     "3"=>18,
#     "4"=>18,
#     "5"=>18,
#     "6"=>18,
#     "7"=>18,
#     "8"=>18,
#     "9"=>13,
#     "a"=>1,
#     "b"=>1,
#     "c"=>1,
#     "d"=>1,
#     "f"=>1,
#     "e"=>1}

# see the logger output
get_captured_output
# => "[2019-03-10 20:08:26.351] DEBUG -- : crawler 2 found 1\n" +
#    "[2019-03-10 20:08:26.352] DEBUG -- : data-processor 0 got 1\n" +
#    "[2019-03-10 20:08:26.353] DEBUG -- : crawler 0 found 2\n" +
#    "[2019-03-10 20:08:26.354] DEBUG -- : data-processor 1 got 2\n" +
#    "[2019-03-10 20:08:26.355] DEBUG -- : crawler 1 found 3\n" +
#    "[2019-03-10 20:08:26.356] DEBUG -- : data-processor 2 got 3\n" +
#    "[2019-03-10 20:08:26.356] DEBUG -- : crawler 3 found 4\n" +
#    "[2019-03-10 20:08:26.357] DEBUG -- : data-processor 3 got 4\n" +
#    "[2019-03-10 20:08:26.361] DEBUG -- : crawler 2 found 5\n" +
#    "[2019-03-10 20:08:26.362] DEBUG -- : data-processor 4 got 5\n" +
#    "[2019-03-10 20:08:26.363] DEBUG -- : crawler 0 found 6\n" +
#    "[2019-03-10 20:08:26.364] DEBUG -- : crawler 1 found 7\n" +
#    "[2019-03-10 20:08:26.364] DEBUG -- : data-processor 5 got 6\n" +
#    "[2019-03-10 20:08:26.365] DEBUG -- : data-processor 6 got 7\n" +
#    "[2019-03-10 20:08:26.366] DEBUG -- : crawler 3 found 8\n" +
#    "[2019-03-10 20:08:26.367] DEBUG -- : data-processor 7 got 8\n" +
#    "[2019-03-10 20:08:26.371] DEBUG -- : crawler 2 found 9\n" +
#    "[2019-03-10 20:08:26.374] DEBUG -- : crawler 0 found a\n" +
#    "[2019-03-10 20:08:26.375] DEBUG -- : crawler 1 found b\n" +
#    "[2019-03-10 20:08:26.377] DEBUG -- : crawler 3 found c\n" +
#    "[2019-03-10 20:08:26.384] DEBUG -- : crawler 2 found d\n" +
#    "[2019-03-10 20:08:26.386] DEBUG -- : crawler 1 found e\n" +
#    "[2019-03-10 20:08:26.386] DEBUG -- : crawler 0 found f\n" +
#    "[2019-03-10 20:08:26.388] DEBUG -- : crawler 3 found 10\n" +
#    "[2019-03-10 20:08:26.396] DEBUG -- : crawler 2 found 11\n" +
#    "[2019-03-10 20:08:26.397] DEBUG -- : crawler 0 found 12\n" +
#    "[2019-03-10 20:08:26.398] DEBUG -- : crawler 1 found 13\n" +
#    "[2019-03-10 20:08:26.400] DEBUG -- : crawler 3 found 14\n" +
#    "[2019-03-10 20:08:26.408] DEBUG -- : crawler 2 found 15\n" +
#    "[2019-03-10 20:08:26.409] DEBUG -- : crawler 0 found 16\n" +
#    "[2019-03-10 20:08:26.411] DEBUG -- : crawler 1 found 17\n" +
#    "[2019-03-10 20:08:26.412] DEBUG -- : crawler 3 found 18\n" +
#    "[2019-03-10 20:08:26.420] DEBUG -- : crawler 2 found 19\n" +
#    "[2019-03-10 20:08:26.421] DEBUG -- : crawler 1 found 1a\n" +
#    "[2019-03-10 20:08:26.423] DEBUG -- : crawler 0 found 1b\n" +
#    "[2019-03-10 20:08:26.425] DEBUG -- : crawler 3 found 1c\n" +
#    "[2019-03-10 20:08:26.431] DEBUG -- : crawler 1 found 1d\n" +
#    "[2019-03-10 20:08:26.432] DEBUG -- : crawler 2 found 1e\n" +
#    "[2019-03-10 20:08:26.454] DEBUG -- : data-processor 8 got 9\n" +
#    "[2019-03-10 20:08:26.456] DEBUG -- : data-processor 9 got a\n" +
#    "[2019-03-10 20:08:26.458] DEBUG -- : data-processor 10 got b\n" +
#    "[2019-03-10 20:08:26.459] DEBUG -- : data-processor 11 got c\n" +
#    "[2019-03-10 20:08:26.466] DEBUG -- : data-processor 12 got d\n" +
#    "[2019-03-10 20:08:26.467] DEBUG -- : data-processor 13 got e\n" +
#    "[2019-03-10 20:08:26.469] DEBUG -- : data-processor 14 got f\n" +
#    "[2019-03-10 20:08:26.470] DEBUG -- : data-processor 15 got 10\n" +
#    "[2019-03-10 20:08:26.558] DEBUG -- : data-processor 16 got 11\n" +
#    "[2019-03-10 20:08:26.560] DEBUG -- : data-processor 17 got 12\n" +
#    "[2019-03-10 20:08:26.562] DEBUG -- : data-processor 18 got 13\n" +
#    "[2019-03-10 20:08:26.564] DEBUG -- : data-processor 19 got 14\n" +
#    "[2019-03-10 20:08:26.575] DEBUG -- : data-processor 1 got 15\n" +
#    "[2019-03-10 20:08:26.576] DEBUG -- : data-processor 0 got 16\n" +
#    "[2019-03-10 20:08:26.577] DEBUG -- : crawler 0 found 1f\n" +
#    "[2019-03-10 20:08:26.579] DEBUG -- : crawler 3 found 20\n" +
#    "[2019-03-10 20:08:26.580] DEBUG -- : crawler 2 found 22\n" +
#    "[2019-03-10 20:08:26.581] DEBUG -- : crawler 1 found 21\n" +
#    "[2019-03-10 20:08:26.581] DEBUG -- : data-processor 2 got 17\n" +
#    "[2019-03-10 20:08:26.582] DEBUG -- : data-processor 3 got 18\n" +
#    "[2019-03-10 20:08:26.587] DEBUG -- : crawler 0 found 23\n" +
#    "[2019-03-10 20:08:26.588] DEBUG -- : crawler 3 found 24\n" +
#    "[2019-03-10 20:08:26.588] DEBUG -- : crawler 2 found 25\n" +
#    "[2019-03-10 20:08:26.589] DEBUG -- : crawler 1 found 26\n" +
#    "[2019-03-10 20:08:26.599] DEBUG -- : crawler 0 found 27\n" +
#    "[2019-03-10 20:08:26.600] DEBUG -- : crawler 2 found 28\n" +
#    "[2019-03-10 20:08:26.601] DEBUG -- : crawler 1 found 29\n" +
#    "[2019-03-10 20:08:26.602] DEBUG -- : crawler 3 found 2a\n" +
#    "[2019-03-10 20:08:26.661] DEBUG -- : data-processor 4 got 19\n" +
#    "[2019-03-10 20:08:26.664] DEBUG -- : data-processor 5 got 1a\n" +
#    "[2019-03-10 20:08:26.667] DEBUG -- : data-processor 6 got 1b\n" +
#    "[2019-03-10 20:08:26.672] DEBUG -- : data-processor 7 got 1c\n" +
#    "[2019-03-10 20:08:26.679] DEBUG -- : data-processor 8 got 1d\n" +
#    "[2019-03-10 20:08:26.680] DEBUG -- : data-processor 9 got 1e\n" +
#    "[2019-03-10 20:08:26.681] DEBUG -- : data-processor 10 got 1f\n" +
#    "[2019-03-10 20:08:26.681] DEBUG -- : data-processor 11 got 20\n" +
#    "[2019-03-10 20:08:26.746]  INFO -- : \n" +
#    "crawlers found: 10, 11, 11, 10\n" +
#    "data processors consumed: 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1\n" +
#    "[2019-03-10 20:08:26.768] DEBUG -- : data-processor 12 got 22\n" +
#    "[2019-03-10 20:08:26.769] DEBUG -- : crawler 1 found 2b\n" +
#    "[2019-03-10 20:08:26.770] DEBUG -- : crawler 0 found 2e\n" +
#    "[2019-03-10 20:08:26.771] DEBUG -- : crawler 2 found 2d\n" +
#    "[2019-03-10 20:08:26.772] DEBUG -- : crawler 3 found 2c\n" +
#    "[2019-03-10 20:08:26.772] DEBUG -- : data-processor 14 got 21\n" +
#    "[2019-03-10 20:08:26.773] DEBUG -- : data-processor 15 got 23\n" +
#    "[2019-03-10 20:08:26.776] DEBUG -- : data-processor 13 got 24\n" +
#    "[2019-03-10 20:08:26.779] DEBUG -- : crawler 1 found 2f\n" +
#    "[2019-03-10 20:08:26.780] DEBUG -- : crawler 0 found 30\n" +
#    "[2019-03-10 20:08:26.780] DEBUG -- : crawler 3 found 31\n" +
#    "[2019-03-10 20:08:26.781] DEBUG -- : crawler 2 found 32\n" +
#    "[2019-03-10 20:08:26.783] DEBUG -- : data-processor 16 got 25\n" +
#    "[2019-03-10 20:08:26.784] DEBUG -- : data-processor 17 got 26\n" +
#    "[2019-03-10 20:08:26.784] DEBUG -- : data-processor 18 got 27\n" +
#    "[2019-03-10 20:08:26.785] DEBUG -- : data-processor 19 got 28\n" +
#    "[2019-03-10 20:08:26.789] DEBUG -- : crawler 0 found 33\n" +
#    "[2019-03-10 20:08:26.790] DEBUG -- : crawler 1 found 34\n" +
#    "[2019-03-10 20:08:26.791] DEBUG -- : crawler 2 found 35\n" +
#    "[2019-03-10 20:08:26.791] DEBUG -- : crawler 3 found 36\n" +
#    "[2019-03-10 20:08:26.800] DEBUG -- : crawler 0 found 37\n" +
#    "[2019-03-10 20:08:26.872] DEBUG -- : data-processor 1 got 29\n" +
#    "[2019-03-10 20:08:26.874] DEBUG -- : data-processor 2 got 2a\n" +
#    "[2019-03-10 20:08:26.876] DEBUG -- : data-processor 3 got 2c\n" +
#    "[2019-03-10 20:08:26.881] DEBUG -- : data-processor 0 got 2b\n" +
#    "[2019-03-10 20:08:26.889] DEBUG -- : data-processor 4 got 2e\n" +
#    "[2019-03-10 20:08:26.890] DEBUG -- : data-processor 5 got 2d\n" +
#    "[2019-03-10 20:08:26.891] DEBUG -- : data-processor 6 got 2f\n" +
#    "[2019-03-10 20:08:26.891] DEBUG -- : data-processor 7 got 30\n" +
#    "[2019-03-10 20:08:26.892] DEBUG -- : crawler 1 found 38\n" +
#    "[2019-03-10 20:08:26.893] DEBUG -- : crawler 3 found 39\n" +
#    "[2019-03-10 20:08:26.894] DEBUG -- : crawler 2 found 3a\n" +
#    "[2019-03-10 20:08:26.894] DEBUG -- : crawler 0 found 3b\n" +
#    "[2019-03-10 20:08:26.902] DEBUG -- : crawler 1 found 3c\n" +
#    "[2019-03-10 20:08:26.903] DEBUG -- : crawler 2 found 3d\n" +
#    "[2019-03-10 20:08:26.904] DEBUG -- : crawler 0 found 3e\n" +
#    "[2019-03-10 20:08:26.904] DEBUG -- : crawler 3 found 3f\n" +
#    "[2019-03-10 20:08:26.915] DEBUG -- : crawler 1 found 40\n" +
#    "[2019-03-10 20:08:26.916] DEBUG -- : crawler 2 found 41\n" +
#    "[2019-03-10 20:08:26.916] DEBUG -- : crawler 3 found 42\n" +
#    "[2019-03-10 20:08:26.977] DEBUG -- : data-processor 8 got 31\n" +
#    "[2019-03-10 20:08:26.978] DEBUG -- : data-processor 11 got 32\n" +
#    "[2019-03-10 20:08:26.980] DEBUG -- : data-processor 10 got 33\n" +
#    "[2019-03-10 20:08:26.984] DEBUG -- : data-processor 9 got 34\n" +
#    "[2019-03-10 20:08:26.992] DEBUG -- : data-processor 12 got 35\n" +
#    "[2019-03-10 20:08:26.994] DEBUG -- : data-processor 14 got 36\n" +
#    "[2019-03-10 20:08:26.995] DEBUG -- : data-processor 15 got 37\n" +
#    "[2019-03-10 20:08:26.996] DEBUG -- : data-processor 13 got 38\n" +
#    "[2019-03-10 20:08:27.089] DEBUG -- : data-processor 16 got 39\n" +
#    "[2019-03-10 20:08:27.090] DEBUG -- : crawler 0 found 43\n" +
#    "[2019-03-10 20:08:27.090] DEBUG -- : crawler 1 found 44\n" +
#    "[2019-03-10 20:08:27.091] DEBUG -- : crawler 2 found 45\n" +
#    "[2019-03-10 20:08:27.092] DEBUG -- : data-processor 19 got 3a\n" +
#    "[2019-03-10 20:08:27.093] DEBUG -- : data-processor 18 got 3b\n" +
#    "[2019-03-10 20:08:27.094] DEBUG -- : data-processor 17 got 3c\n" +
#    "[2019-03-10 20:08:27.095] DEBUG -- : crawler 3 found 46\n" +
#    "[2019-03-10 20:08:27.097] DEBUG -- : data-processor 1 got 3d\n" +
#    "[2019-03-10 20:08:27.098] DEBUG -- : data-processor 2 got 3e\n" +
#    "[2019-03-10 20:08:27.099] DEBUG -- : data-processor 3 got 3f\n" +
#    "[2019-03-10 20:08:27.100] DEBUG -- : data-processor 0 got 40\n" +
#    "[2019-03-10 20:08:27.101] DEBUG -- : crawler 0 found 47\n" +
#    "[2019-03-10 20:08:27.102] DEBUG -- : crawler 2 found 48\n" +
#    "[2019-03-10 20:08:27.102] DEBUG -- : crawler 1 found 49\n" +
#    "[2019-03-10 20:08:27.103] DEBUG -- : crawler 3 found 4a\n" +
#    "[2019-03-10 20:08:27.111] DEBUG -- : crawler 1 found 4b\n" +
#    "[2019-03-10 20:08:27.112] DEBUG -- : crawler 0 found 4c\n" +
#    "[2019-03-10 20:08:27.113] DEBUG -- : crawler 2 found 4d\n" +
#    "[2019-03-10 20:08:27.115] DEBUG -- : crawler 3 found 4e\n" +
#    "[2019-03-10 20:08:27.121] DEBUG -- : crawler 0 found 4f\n" +
#    "[2019-03-10 20:08:27.149]  INFO -- : \n" +
#    "crawlers found: 20, 20, 20, 19\n" +
#    "data processors consumed: 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3\n" +
#    "[2019-03-10 20:08:27.194] DEBUG -- : data-processor 4 got 41\n" +
#    "[2019-03-10 20:08:27.196] DEBUG -- : data-processor 5 got 42\n" +
#    "[2019-03-10 20:08:27.197] DEBUG -- : data-processor 7 got 43\n" +
#    "[2019-03-10 20:08:27.198] DEBUG -- : data-processor 6 got 44\n" +
#    "[2019-03-10 20:08:27.206] DEBUG -- : data-processor 8 got 46\n" +
#    "[2019-03-10 20:08:27.207] DEBUG -- : data-processor 10 got 45\n" +
#    "[2019-03-10 20:08:27.207] DEBUG -- : data-processor 9 got 47\n" +
#    "[2019-03-10 20:08:27.208] DEBUG -- : data-processor 11 got 48\n" +
#    "[2019-03-10 20:08:27.209] DEBUG -- : crawler 1 found 50\n" +
#    "[2019-03-10 20:08:27.210] DEBUG -- : crawler 2 found 51\n" +
#    "[2019-03-10 20:08:27.212] DEBUG -- : crawler 3 found 52\n" +
#    "[2019-03-10 20:08:27.213] DEBUG -- : crawler 0 found 53\n" +
#    "[2019-03-10 20:08:27.216] DEBUG -- : crawler 0 found 54\n" +
#    "[2019-03-10 20:08:27.218] DEBUG -- : crawler 1 found 55\n" +
#    "[2019-03-10 20:08:27.219] DEBUG -- : crawler 2 found 56\n" +
#    "[2019-03-10 20:08:27.221] DEBUG -- : crawler 3 found 57\n" +
#    "[2019-03-10 20:08:27.228] DEBUG -- : crawler 1 found 58\n" +
#    "[2019-03-10 20:08:27.229] DEBUG -- : crawler 0 found 59\n" +
#    "[2019-03-10 20:08:27.230] DEBUG -- : crawler 3 found 5a\n" +
#    "[2019-03-10 20:08:27.299] DEBUG -- : data-processor 12 got 49\n" +
#    "[2019-03-10 20:08:27.300] DEBUG -- : data-processor 14 got 4a\n" +
#    "[2019-03-10 20:08:27.301] DEBUG -- : data-processor 15 got 4b\n" +
#    "[2019-03-10 20:08:27.302] DEBUG -- : data-processor 13 got 4c\n" +
#    "[2019-03-10 20:08:27.305] DEBUG -- : data-processor 16 got 4d\n" +
#    "[2019-03-10 20:08:27.309] DEBUG -- : data-processor 19 got 4e\n" +
#    "[2019-03-10 20:08:27.310] DEBUG -- : data-processor 18 got 4f\n" +
#    "[2019-03-10 20:08:27.311] DEBUG -- : data-processor 17 got 50\n" +
#    "[2019-03-10 20:08:27.420] DEBUG -- : crawler 1 found 5c\n" +
#    "[2019-03-10 20:08:27.426] DEBUG -- : data-processor 3 got 51\n" +
#    "[2019-03-10 20:08:27.434] DEBUG -- : data-processor 2 got 52\n" +
#    "[2019-03-10 20:08:27.437] DEBUG -- : crawler 2 found 5b\n" +
#    "[2019-03-10 20:08:27.440] DEBUG -- : data-processor 0 got 53\n" +
#    "[2019-03-10 20:08:27.442] DEBUG -- : data-processor 1 got 54\n" +
#    "[2019-03-10 20:08:27.444] DEBUG -- : data-processor 7 got 55\n" +
#    "[2019-03-10 20:08:27.445] DEBUG -- : data-processor 6 got 56\n" +
#    "[2019-03-10 20:08:27.445] DEBUG -- : crawler 1 found 5f\n" +
#    "[2019-03-10 20:08:27.446] DEBUG -- : crawler 3 found 5e\n" +
#    "[2019-03-10 20:08:27.447] DEBUG -- : crawler 0 found 5d\n" +
#    "[2019-03-10 20:08:27.447] DEBUG -- : crawler 2 found 60\n" +
#    "[2019-03-10 20:08:27.449] DEBUG -- : data-processor 4 got 57\n" +
#    "[2019-03-10 20:08:27.449] DEBUG -- : data-processor 5 got 58\n" +
#    "[2019-03-10 20:08:27.450] DEBUG -- : crawler 0 found 61\n" +
#    "[2019-03-10 20:08:27.451] DEBUG -- : crawler 3 found 62\n" +
#    "[2019-03-10 20:08:27.452] DEBUG -- : crawler 1 found 63\n" +
#    "[2019-03-10 20:08:27.452] DEBUG -- : crawler 2 found 64\n" +
#    "[2019-03-10 20:08:27.456] DEBUG -- : crawler 0 found 65\n" +
#    "[2019-03-10 20:08:27.457] DEBUG -- : crawler 2 found 66\n" +
#    "[2019-03-10 20:08:27.457] DEBUG -- : crawler 3 found 67\n" +
#    "[2019-03-10 20:08:27.512] DEBUG -- : data-processor 8 got 59\n" +
#    "[2019-03-10 20:08:27.519] DEBUG -- : data-processor 10 got 5a\n" +
#    "[2019-03-10 20:08:27.526] DEBUG -- : data-processor 9 got 5b\n" +
#    "[2019-03-10 20:08:27.533] DEBUG -- : data-processor 11 got 5c\n" +
#    "[2019-03-10 20:08:27.537] DEBUG -- : data-processor 12 got 5e\n" +
#    "[2019-03-10 20:08:27.543] DEBUG -- : crawler 1 found 68\n" +
#    "[2019-03-10 20:08:27.549] DEBUG -- : data-processor 16 got 5d\n" +
#    "[2019-03-10 20:08:27.554] DEBUG -- : crawler 1 found 6c\n" +
#    "[2019-03-10 20:08:27.558] DEBUG -- : crawler 2 found 69\n" +
#    "[2019-03-10 20:08:27.562] DEBUG -- : crawler 0 found 6a\n" +
#    "[2019-03-10 20:08:27.569] DEBUG -- : data-processor 14 got 5f\n" +
#    "[2019-03-10 20:08:27.573] DEBUG -- : data-processor 15 got 60\n" +
#    "[2019-03-10 20:08:27.575] DEBUG -- : crawler 3 found 6b\n" +
#    "[2019-03-10 20:08:27.577] DEBUG -- : crawler 0 found 6d\n" +
#    "[2019-03-10 20:08:27.578]  INFO -- : \n" +
#    "crawlers found: 28, 28, 27, 26\n" +
#    "data processors consumed: 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 5, 4, 4, 4\n" +
#    "[2019-03-10 20:08:27.579] DEBUG -- : crawler 1 found 6e\n" +
#    "[2019-03-10 20:08:27.580] DEBUG -- : crawler 2 found 6f\n" +
#    "[2019-03-10 20:08:27.580] DEBUG -- : crawler 3 found 70\n" +
#    "[2019-03-10 20:08:27.581] DEBUG -- : crawler 0 found 71\n" +
#    "[2019-03-10 20:08:27.582] DEBUG -- : crawler 1 found 72\n" +
#    "[2019-03-10 20:08:27.583] DEBUG -- : crawler 2 found 73\n" +
#    "[2019-03-10 20:08:27.615] DEBUG -- : data-processor 13 got 61\n" +
#    "[2019-03-10 20:08:27.621] DEBUG -- : data-processor 19 got 62\n" +
#    "[2019-03-10 20:08:27.629] DEBUG -- : data-processor 17 got 63\n" +
#    "[2019-03-10 20:08:27.630] DEBUG -- : data-processor 18 got 64\n" +
#    "[2019-03-10 20:08:27.631] DEBUG -- : data-processor 3 got 65\n" +
#    "[2019-03-10 20:08:27.638] DEBUG -- : data-processor 2 got 66\n" +
#    "[2019-03-10 20:08:27.654] DEBUG -- : data-processor 0 got 67\n" +
#    "[2019-03-10 20:08:27.654] DEBUG -- : data-processor 7 got 68\n" +
#    "[2019-03-10 20:08:27.719] DEBUG -- : data-processor 1 got 69\n" +
#    "[2019-03-10 20:08:27.719] DEBUG -- : crawler 3 found 74\n" +
#    "[2019-03-10 20:08:27.727] DEBUG -- : data-processor 6 got 6a\n" +
#    "[2019-03-10 20:08:27.728] DEBUG -- : crawler 0 found 75\n" +
#    "[2019-03-10 20:08:27.729] DEBUG -- : crawler 2 found 77\n" +
#    "[2019-03-10 20:08:27.731] DEBUG -- : crawler 1 found 76\n" +
#    "[2019-03-10 20:08:27.732] DEBUG -- : crawler 3 found 78\n" +
#    "[2019-03-10 20:08:27.734] DEBUG -- : data-processor 5 got 6b\n" +
#    "[2019-03-10 20:08:27.736] DEBUG -- : data-processor 4 got 6c\n" +
#    "[2019-03-10 20:08:27.737] DEBUG -- : data-processor 8 got 6d\n" +
#    "[2019-03-10 20:08:27.739] DEBUG -- : crawler 0 found 79\n" +
#    "[2019-03-10 20:08:27.740] DEBUG -- : crawler 1 found 7a\n" +
#    "[2019-03-10 20:08:27.741] DEBUG -- : crawler 2 found 7b\n" +
#    "[2019-03-10 20:08:27.744] DEBUG -- : data-processor 10 got 6e\n" +
#    "[2019-03-10 20:08:27.745] DEBUG -- : crawler 3 found 7c\n" +
#    "[2019-03-10 20:08:27.747] DEBUG -- : crawler 0 found 7d\n" +
#    "[2019-03-10 20:08:27.750] DEBUG -- : crawler 1 found 7e\n" +
#    "[2019-03-10 20:08:27.752] DEBUG -- : crawler 2 found 7f\n" +
#    "[2019-03-10 20:08:27.755] DEBUG -- : crawler 3 found 80\n" +
#    "[2019-03-10 20:08:27.756] DEBUG -- : data-processor 9 got 6f\n" +
#    "[2019-03-10 20:08:27.757] DEBUG -- : data-processor 11 got 70\n" +
#    "[2019-03-10 20:08:27.823] DEBUG -- : data-processor 12 got 71\n" +
#    "[2019-03-10 20:08:27.829] DEBUG -- : data-processor 16 got 72\n" +
#    "[2019-03-10 20:08:27.836] DEBUG -- : data-processor 15 got 73\n" +
#    "[2019-03-10 20:08:27.837] DEBUG -- : data-processor 14 got 74\n" +
#    "[2019-03-10 20:08:27.838] DEBUG -- : data-processor 13 got 75\n" +
#    "[2019-03-10 20:08:27.847] DEBUG -- : data-processor 19 got 77\n" +
#    "[2019-03-10 20:08:27.862] DEBUG -- : data-processor 17 got 76\n" +
#    "[2019-03-10 20:08:27.863] DEBUG -- : crawler 0 found 81\n" +
#    "[2019-03-10 20:08:27.864] DEBUG -- : crawler 1 found 82\n" +
#    "[2019-03-10 20:08:27.864] DEBUG -- : crawler 2 found 83\n" +
#    "[2019-03-10 20:08:27.865] DEBUG -- : crawler 3 found 84\n" +
#    "[2019-03-10 20:08:27.865] DEBUG -- : data-processor 18 got 78\n" +
#    "[2019-03-10 20:08:27.873] DEBUG -- : crawler 1 found 85\n" +
#    "[2019-03-10 20:08:27.873] DEBUG -- : crawler 0 found 86\n" +
#    "[2019-03-10 20:08:27.874] DEBUG -- : crawler 2 found 87\n" +
#    "[2019-03-10 20:08:27.875] DEBUG -- : crawler 3 found 88\n" +
#    "[2019-03-10 20:08:27.884] DEBUG -- : crawler 1 found 89\n" +
#    "[2019-03-10 20:08:27.885] DEBUG -- : crawler 3 found 8a\n" +
#    "[2019-03-10 20:08:27.885] DEBUG -- : crawler 2 found 8b\n" +
#    "[2019-03-10 20:08:27.886] DEBUG -- : crawler 0 found 8c\n" +
#    "[2019-03-10 20:08:27.928] DEBUG -- : data-processor 3 got 79\n" +
#    "[2019-03-10 20:08:27.933] DEBUG -- : data-processor 2 got 7a\n" +
#    "[2019-03-10 20:08:27.940] DEBUG -- : data-processor 7 got 7b\n" +
#    "[2019-03-10 20:08:27.943] DEBUG -- : data-processor 0 got 7c\n" +
#    "[2019-03-10 20:08:27.944] DEBUG -- : data-processor 1 got 7d\n" +
#    "[2019-03-10 20:08:27.949] DEBUG -- : data-processor 6 got 7e\n" +
#    "[2019-03-10 20:08:27.967] DEBUG -- : data-processor 5 got 7f\n" +
#    "[2019-03-10 20:08:27.968] DEBUG -- : data-processor 4 got 80\n" +
#    "[2019-03-10 20:08:27.972]  INFO -- : \n" +
#    "crawlers found: 35, 36, 35, 34\n" +
#    "data processors consumed: 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6\n" +
#    "[2019-03-10 20:08:28.033] DEBUG -- : data-processor 8 got 81\n" +
#    "[2019-03-10 20:08:28.038] DEBUG -- : data-processor 10 got 82\n" +
#    "[2019-03-10 20:08:28.047] DEBUG -- : data-processor 9 got 83\n" +
#    "[2019-03-10 20:08:28.049] DEBUG -- : crawler 3 found 8e\n" +
#    "[2019-03-10 20:08:28.049] DEBUG -- : crawler 1 found 8d\n" +
#    "[2019-03-10 20:08:28.050] DEBUG -- : crawler 0 found 90\n" +
#    "[2019-03-10 20:08:28.051] DEBUG -- : crawler 2 found 8f\n" +
#    "[2019-03-10 20:08:28.052] DEBUG -- : data-processor 11 got 84\n" +
#    "[2019-03-10 20:08:28.053] DEBUG -- : data-processor 12 got 85\n" +
#    "[2019-03-10 20:08:28.053] DEBUG -- : data-processor 16 got 86\n" +
#    "[2019-03-10 20:08:28.059] DEBUG -- : crawler 3 found 91\n" +
#    "[2019-03-10 20:08:28.060] DEBUG -- : crawler 1 found 92\n" +
#    "[2019-03-10 20:08:28.061] DEBUG -- : crawler 2 found 93\n" +
#    "[2019-03-10 20:08:28.062] DEBUG -- : crawler 0 found 94\n" +
#    "[2019-03-10 20:08:28.072] DEBUG -- : crawler 3 found 95\n" +
#    "[2019-03-10 20:08:28.073] DEBUG -- : crawler 1 found 96\n" +
#    "[2019-03-10 20:08:28.074] DEBUG -- : crawler 0 found 97\n" +
#    "[2019-03-10 20:08:28.075] DEBUG -- : data-processor 15 got 87\n" +
#    "[2019-03-10 20:08:28.076] DEBUG -- : data-processor 14 got 88\n" +
#    "[2019-03-10 20:08:28.076] DEBUG -- : crawler 2 found 98\n" +
#    "[2019-03-10 20:08:28.139] DEBUG -- : data-processor 13 got 89\n" +
#    "[2019-03-10 20:08:28.143] DEBUG -- : data-processor 19 got 8a\n" +
#    "[2019-03-10 20:08:28.150] DEBUG -- : data-processor 17 got 8b\n" +
#    "[2019-03-10 20:08:28.153] DEBUG -- : data-processor 18 got 8c\n" +
#    "[2019-03-10 20:08:28.154] DEBUG -- : data-processor 3 got 8e\n" +
#    "[2019-03-10 20:08:28.155] DEBUG -- : data-processor 2 got 8d\n" +
#    "[2019-03-10 20:08:28.180] DEBUG -- : data-processor 7 got 90\n" +
#    "[2019-03-10 20:08:28.180] DEBUG -- : crawler 3 found 99\n" +
#    "[2019-03-10 20:08:28.181] DEBUG -- : crawler 1 found 9a\n" +
#    "[2019-03-10 20:08:28.182] DEBUG -- : crawler 0 found 9b\n" +
#    "[2019-03-10 20:08:28.183] DEBUG -- : crawler 2 found 9c\n" +
#    "[2019-03-10 20:08:28.184] DEBUG -- : data-processor 0 got 8f\n" +
#    "[2019-03-10 20:08:28.192] DEBUG -- : crawler 3 found 9d\n" +
#    "[2019-03-10 20:08:28.193] DEBUG -- : crawler 1 found 9e\n" +
#    "[2019-03-10 20:08:28.194] DEBUG -- : crawler 2 found 9f\n" +
#    "[2019-03-10 20:08:28.195] DEBUG -- : crawler 0 found a0\n" +
#    "[2019-03-10 20:08:28.203] DEBUG -- : crawler 3 found a1\n" +
#    "[2019-03-10 20:08:28.205] DEBUG -- : crawler 1 found a2\n" +
#    "[2019-03-10 20:08:28.206] DEBUG -- : crawler 2 found a3\n" +
#    "[2019-03-10 20:08:28.207] DEBUG -- : crawler 0 found a4\n" +
#    "[2019-03-10 20:08:28.243] DEBUG -- : data-processor 1 got 91\n" +
#    "[2019-03-10 20:08:28.248] DEBUG -- : data-processor 6 got 92\n" +
#    "[2019-03-10 20:08:28.255] DEBUG -- : data-processor 4 got 93\n" +
#    "[2019-03-10 20:08:28.256] DEBUG -- : data-processor 5 got 94\n" +
#    "[2019-03-10 20:08:28.257] DEBUG -- : data-processor 8 got 95\n" +
#    "[2019-03-10 20:08:28.259] DEBUG -- : data-processor 10 got 96\n" +
#    "[2019-03-10 20:08:28.285] DEBUG -- : data-processor 12 got 97\n" +
#    "[2019-03-10 20:08:28.286] DEBUG -- : data-processor 9 got 98\n" +
#    "[2019-03-10 20:08:28.343]  INFO -- : \n" +
#    "crawlers found: 41, 42, 41, 40\n" +
#    "data processors consumed: 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 8, 7, 7, 7, 7, 7, 7, 7\n" +
#    "[2019-03-10 20:08:28.344] DEBUG -- : data-processor 11 got 99\n" +
#    "[2019-03-10 20:08:28.350] DEBUG -- : data-processor 16 got 9a\n" +
#    "[2019-03-10 20:08:28.426] DEBUG -- : crawler 1 found a6\n" +
#    "[2019-03-10 20:08:28.428] DEBUG -- : crawler 3 found a5\n" +
#    "[2019-03-10 20:08:28.429] DEBUG -- : crawler 0 found a8\n" +
#    "[2019-03-10 20:08:28.429] DEBUG -- : crawler 2 found a7\n"




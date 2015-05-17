require 'concurrent/configuration'
require 'concurrent/executor/timer_set'

module Concurrent

  # `ScheduledTask` is a close relative of `Concurrent::Future` but with one
  # important difference: A `Future` is set to execute as soon as possible
  # whereas a `ScheduledTask` is set to execute after a specified delay. This
  # implementation is loosely based on Java's
  # [ScheduledExecutorService](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ScheduledExecutorService.html). 
  # 
  # The *intended* schedule time of task execution is set on object construction
  # with the `delay` argument. The delay is a numeric (floating point or integer)
  # representing a number of seconds in the future. Any other value or a numeric
  # equal to or less than zero will result in an exception. The *actual* schedule
  # time of task execution is set when the `execute` method is called.
  #  
  # The constructor can also be given zero or more processing options. Currently
  # the only supported options are those recognized by the
  # [Dereferenceable](Dereferenceable) module. 
  # 
  # The final constructor argument is a block representing the task to be performed.
  # If no block is given an `ArgumentError` will be raised.
  # 
  # **States**
  # 
  # `ScheduledTask` mixes in the  [Obligation](Obligation) module thus giving it
  # "future" behavior. This includes the expected lifecycle states. `ScheduledTask`
  # has one additional state, however. While the task (block) is being executed the
  # state of the object will be `:processing`. This additional state is necessary
  # because it has implications for task cancellation. 
  # 
  # **Cancellation**
  # 
  # A `:pending` task can be cancelled using the `#cancel` method. A task in any
  # other state, including `:processing`, cannot be cancelled. The `#cancel`
  # method returns a boolean indicating the success of the cancellation attempt.
  # A cancelled `ScheduledTask` cannot be restarted. It is immutable. 
  # 
  # **Obligation and Observation**
  # 
  # The result of a `ScheduledTask` can be obtained either synchronously or
  # asynchronously. `ScheduledTask` mixes in both the [Obligation](Obligation)
  # module and the
  # [Observable](http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html)
  # module from the Ruby standard library. With one exception `ScheduledTask`
  # behaves identically to [Future](Observable) with regard to these modules. 
  #
  # @example Basic usage
  #
  #   require 'concurrent'
  #   require 'thread'   # for Queue
  #   require 'open-uri' # for open(uri)
  #   
  #   class Ticker
  #     def get_year_end_closing(symbol, year)
  #       uri = "http://ichart.finance.yahoo.com/table.csv?s=#{symbol}&a=11&b=01&c=#{year}&d=11&e=31&f=#{year}&g=m"
  #       data = open(uri) {|f| f.collect{|line| line.strip } }
  #       data[1].split(',')[4].to_f
  #     end
  #   end
  #   
  #   # Future
  #   price = Concurrent::Future.execute{ Ticker.new.get_year_end_closing('TWTR', 2013) }
  #   price.state #=> :pending
  #   sleep(1)    # do other stuff
  #   price.value #=> 63.65
  #   price.state #=> :fulfilled
  #   
  #   # ScheduledTask
  #   task = Concurrent::ScheduledTask.execute(2){ Ticker.new.get_year_end_closing('INTC', 2013) }
  #   task.state #=> :pending
  #   sleep(3)   # do other stuff
  #   task.value #=> 25.96
  # 
  # @example Successful task execution
  #   
  #   task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }
  #   task.state         #=> :unscheduled
  #   task.execute
  #   task.state         #=> pending
  #   
  #   # wait for it...
  #   sleep(3)
  #   
  #   task.unscheduled? #=> false
  #   task.pending?     #=> false
  #   task.fulfilled?   #=> true
  #   task.rejected?    #=> false
  #   task.value        #=> 'What does the fox say?'
  # 
  # @example One line creation and execution
  # 
  #   task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }.execute
  #   task.state         #=> pending
  # 
  #   task = Concurrent::ScheduledTask.execute(2){ 'What do you get when you multiply 6 by 9?' }
  #   task.state         #=> pending
  # 
  # @example Failed task execution
  # 
  #   task = Concurrent::ScheduledTask.execute(2){ raise StandardError.new('Call me maybe?') }
  #   task.pending?      #=> true
  #   
  #   # wait for it...
  #   sleep(3)
  #   
  #   task.unscheduled? #=> false
  #   task.pending?     #=> false
  #   task.fulfilled?   #=> false
  #   task.rejected?    #=> true
  #   task.value        #=> nil
  #   task.reason       #=> #<StandardError: Call me maybe?> 
  # 
  # @example Task execution with observation
  # 
  #   observer = Class.new{
  #     def update(time, value, reason)
  #       puts "The task completed at #{time} with value '#{value}'"
  #     end
  #   }.new
  #   
  #   task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }
  #   task.add_observer(observer)
  #   task.execute
  #   task.pending?      #=> true
  #   
  #   # wait for it...
  #   sleep(3)
  #   
  #   #>> The task completed at 2013-11-07 12:26:09 -0500 with value 'What does the fox say?'
  #
  # @!macro monotonic_clock_warning
  class ScheduledTask < TimerSet::Task

    # Schedule a task for execution at a specified future time.
    #
    # @yield the task to be performed
    #
    # @param [Float] delay the number of seconds to wait for before executing the task
    #
    # @!macro executor_and_deref_options
    #
    # @!macro [attach] deprecated_scheduling_by_clock_time
    #
    #   @note Scheduling is now based on a monotonic clock. This makes the timer much
    #     more accurate, but only when scheduling based on a delay interval.
    #     Scheduling a task based on a clock time is deprecated. It will still work
    #     but will not be supported in the 1.0 release.
    def initialize(delay, opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      super(Concurrent.global_timer_set, delay, [], block, &nil)
      synchronize do
        ns_set_state(:unscheduled)
        @__original_delay__ = delay
        @time = nil
      end
    end

    # Execute an `:unscheduled` `ScheduledTask`. Immediately sets the state to `:pending`
    # and starts counting down toward execution. Does nothing if the `ScheduledTask` is
    # in any state other than `:unscheduled`.
    #
    # @return [ScheduledTask] a reference to `self`
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        synchronize{ ns_reschedule(@__original_delay__, false) }
      end
      self
    end

    # Create a new `ScheduledTask` object with the given block, execute it, and return the
    # `:pending` object.
    #
    # @param [Float] delay the number of seconds to wait for before executing the task
    #
    # @!macro executor_and_deref_options
    #
    # @return [ScheduledTask] the newly created `ScheduledTask` in the `:pending` state
    #
    # @raise [ArgumentError] if no block is given
    #
    # @!macro deprecated_scheduling_by_clock_time
    def self.execute(delay, opts = {}, &block)
      new(delay, &block).execute
    end

    # In the task execution in progress?
    #
    # @return [Boolean] true if the task is in the given state else false
    #
    # @deprecated
    def in_progress?
      warn '[DEPRECATED] use #processing? instead'
      processing?
    end

    # Cancel this task and prevent it from executing. A task can only be
    # cancelled if it is pending or unscheduled.
    #
    # @return [Boolean] true if task execution is successfully cancelled
    #   else false
    #
    # @deprecated
    def stop
      warn '[DEPRECATED] use #processing? instead'
      cancel
    end

    # @deprecated
    def delay
      warn '[DEPRECATED] use #original_delay instead'
      original_delay
    end
  end
end

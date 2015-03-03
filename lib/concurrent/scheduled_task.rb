require 'concurrent/ivar'
require 'concurrent/utility/timer'
require 'concurrent/executor/safe_task_executor'

module Concurrent

  # `ScheduledTask` is a close relative of `Concurrent::Future` but with one
  # important difference. A `Future` is set to execute as soon as possible
  # whereas a `ScheduledTask` is set to execute at a specific time. This
  # implementation is loosely based on Java's
  # [ScheduledExecutorService](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ScheduledExecutorService.html). 
  # 
  # The *intended* schedule time of task execution is set on object construction
  # with first argument, `delay`. The delay is a numeric (floating point or integer)
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
  # state of the object will be `:in_progress`. This additional state is necessary
  # because it has implications for task cancellation. 
  # 
  # **Cancellation**
  # 
  # A `:pending` task can be cancelled using the `#cancel` method. A task in any
  # other state, including `:in_progress`, cannot be cancelled. The `#cancel`
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
  #
  # @!macro [attach] deprecated_scheduling_by_clock_time
  #
  #   @note Scheduling is now based on a monotonic clock. This makes the timer much
  #     more accurate, but only when scheduling by passing a delay in seconds.
  #     Scheduling a task based on a clock time is deprecated. It will still work
  #     but will not be supported in the 1.0 release.
  class ScheduledTask < IVar

    attr_reader :delay

    # @!macro deprecated_scheduling_by_clock_time
    def initialize(delay, opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      @delay = TimerSet.calculate_interval(delay)

      super(NO_VALUE, opts)

      self.observers = CopyOnNotifyObserverSet.new
      @state         = :unscheduled
      @task          = block
      @executor      = OptionsParser::get_executor_from(opts) || Concurrent.configuration.global_operation_pool
    end

    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @schedule_time = Time.now + @delay
        Concurrent::timer(@delay) { @executor.post(&method(:process_task)) }
        self
      end
    end

    # @!macro deprecated_scheduling_by_clock_time
    def self.execute(delay, opts = {}, &block)
      return ScheduledTask.new(delay, opts, &block).execute
    end

    # @deprecated
    def schedule_time
      warn '[DEPRECATED] time is now based on a monotonic clock'
      @schedule_time
    end

    def cancelled?
      state == :cancelled
    end

    def in_progress?
      state == :in_progress
    end

    def cancel
      if_state(:unscheduled, :pending) do
        @state = :cancelled
        event.set
        true
      end
    end
    alias_method :stop, :cancel

    protected :set, :fail, :complete

    private

    def process_task
      if compare_and_set_state(:in_progress, :pending)
        success, val, reason = SafeTaskExecutor.new(@task).execute

        mutex.synchronize do
          set_state(success, val, reason)
          event.set
        end

        time = Time.now
        observers.notify_and_delete_observers { [time, self.value, reason] }
      end
    end
  end
end

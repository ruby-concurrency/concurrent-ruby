module Concurrent

  # A very common concurrency pattern is to run a thread that performs a task at
  # regular intervals. The thread that performs the task sleeps for the given
  # interval then wakes up and performs the task. Lather, rinse, repeat... This
  # pattern causes two problems. First, it is difficult to test the business
  # logic of the task because the task itself is tightly coupled with the
  # concurrency logic. Second, an exception raised while performing the task can
  # cause the entire thread to abend. In a long-running application where the
  # task thread is intended to run for days/weeks/years a crashed task thread
  # can pose a significant problem. `TimerTask2` alleviates both problems.
  #
  # When a `TimerTask2` is launched it starts a thread for monitoring the
  # execution interval. The `TimerTask2` thread does not perform the task,
  # however. Instead, the TimerTask2 launches the task on a separate thread.
  # Should the task experience an unrecoverable crash only the task thread will
  # crash. This makes the `TimerTask2` very fault tolerant. Additionally, the
  # `TimerTask2` thread can respond to the success or failure of the task,
  # performing logging or ancillary operations. `TimerTask2` can also be
  # configured with a timeout value allowing it to kill a task that runs too
  # long.
  #
  # One other advantage of `TimerTask2` is that it forces the business logic to
  # be completely decoupled from the concurrency logic. The business logic can
  # be tested separately then passed to the `TimerTask2` for scheduling and
  # running.
  #
  # In some cases it may be necessary for a `TimerTask2` to affect its own
  # execution cycle. To facilitate this, a reference to the TimerTask2 instance
  # is passed as an argument to the provided block every time the task is
  # executed.
  #
  # @example Basic usage
  #   task = Concurrent::TimerTask2.new{ puts 'Boom!' }
  #   task.execute
  #
  #   task.execution_interval #=> 60 (default)
  #   task.timeout_interval   #=> 30 (default)
  #
  #   # wait 60 seconds...
  #   #=> 'Boom!'
  #
  #   task.shutdown #=> true
  #
  # @example Configuring `:execution_interval` and `:timeout_interval`
  #   task = Concurrent::TimerTask2.new(execution_interval: 5, timeout_interval: 5) do
  #     puts 'Boom!'
  #   end
  #
  #   task.execution_interval #=> 5
  #   task.timeout_interval   #=> 5
  #
  # @example Immediate execution with `:run_now`
  #   task = Concurrent::TimerTask2.new(run_now: true){ puts 'Boom!' }
  #   task.execute
  #
  #   #=> 'Boom!'
  #
  # @example Controlling execution from within the block
  #   channel = Concurrent::Promises::Channel.new 1
  #   timer_task = Concurrent::TimerTask2.new(execution_interval: 1, channel: channel) do |task, cancellation|
  #     task.execution_interval.to_i.times{ print 'Boom! ' }
  #     print "\n"
  #     task.execution_interval += 1
  #     if task.execution_interval > 5
  #       puts 'Stopping...'
  #       task.shutdown
  #     end
  #   end
  #
  #   timer_task.execute # non-blocking call
  #   6.times { channel.pop }
  #   #=> Boom!
  #   #=> Boom! Boom!
  #   #=> Boom! Boom! Boom!
  #   #=> Boom! Boom! Boom! Boom!
  #   #=> Boom! Boom! Boom! Boom! Boom!
  #   #=> Stopping...
  #
  # @example Observation
  #   channel = Concurrent::Promises::Channel.new
  #   observe = ->(channel) do
  #     channel.pop_op.then do |(success, result, error)|
  #       if success
  #         print "(#{success}) Execution successfully returned #{result}\n"
  #       else
  #         if error.is_a?(Concurrent::TimeoutError)
  #           print "(#{success}) Execution timed out\n"
  #         else
  #           print "(#{success}) Execution failed with error #{error}\n"
  #         end
  #       end
  #     end
  #   end
  #
  #   task = Concurrent::TimerTask2.new(execution_interval: 1, timeout_interval: 1, channel: channel){ 42 }
  #   task.execute
  #
  #   3.times do
  #     observe.call(channel).wait
  #   end
  #
  #   #=> (true) Execution successfully returned 42
  #   #=> (true) Execution successfully returned 42
  #   #=> (true) Execution successfully returned 42
  #   task.shutdown
  #
  #   task = Concurrent::TimerTask2.new(execution_interval: 1, timeout_interval: 0.1, channel: channel) do |_, cancellation|
  #     until cancellation.cancelled?
  #       sleep 0.1 # Simulate doing work
  #     end
  #
  #     raise Concurrent::TimeoutError.new
  #   end
  #   task.execute
  #
  #   3.times do
  #     observe.call(channel).wait
  #   end
  #   #=> (false) Execution timed out
  #   #=> (false) Execution timed out
  #   #=> (false) Execution timed out
  #   task.shutdown
  #
  #   task = Concurrent::TimerTask2.new(execution_interval: 1, channel: channel){ raise StandardError }
  #   task.execute
  #
  #   3.times do
  #     observe.call(channel).wait
  #   end
  #   #=> (false) Execution failed with error StandardError
  #   #=> (false) Execution failed with error StandardError
  #   #=> (false) Execution failed with error StandardError
  #   task.shutdown
  #   channel.pop
  #
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/TimerTask.html
  class TimerTask2 < ::Concurrent::Synchronization::Object
    safe_initialization!

    # Default `:execution_interval` in seconds.
    EXECUTION_INTERVAL = 60
    # Default `:timeout_interval` in seconds.
    TIMEOUT_INTERVAL = 30

    # Create a new TimerTask2 with the given task and configuration.
    #
    # @!macro timer_task_initialize
    #   @param [Hash] opts the options defining task execution.
    #   @option opts [Integer] :execution_interval number of seconds between
    #     task executions (default: EXECUTION_INTERVAL)
    #   @option opts [Integer] :timeout_interval number of seconds a task can
    #     run before it is considered to have failed (default: TIMEOUT_INTERVAL)
    #   @option opts [Boolean] :run_now Whether to run the task immediately
    #     upon instantiation or to wait until the first execution_interval
    #     has passed (default: false)
    #   @option opts [Symbol] :reschedule when to schedule next execution relative,
    #     relative to a current one, `:before` or `:after` (default: :after)
    #   @option opts [Promises::Channel, nil] :channel if given, execution results
    #     will be pushed into the channel (default: nil)
    #
    #   @raise ArgumentError when no block is given.
    #
    #   @yield to the block after :execution_interval seconds have passed since
    #     the last yield
    #   @yieldparam task a reference to the `TimerTask` instance so that the
    #     block can control its own lifecycle. Necessary since `self` will
    #     refer to the execution context of the block rather than the running
    #     `TimerTask`.
    #   @yieldparam cancellation a cancellation object representing the joined cancellation
    #     of the timer task and this run's timeout
    #
    #   @return [TimerTask] the new `TimerTask`
    def initialize(opts = {}, &task)
      raise ArgumentError.new('no block given') unless block_given?
      raise ArgumentError.new('reschedule must be either :before or :after') unless [nil, :before, :after].include?(opts[:reschedule])
      @ExecutionInterval = AtomicReference.new nil
      @TimeoutInterval = AtomicReference.new nil
      @Cancellation = AtomicReference.new nil

      self.execution_interval = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      self.timeout_interval = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL

      @Channel = opts[:channel]

      @Executor = SafeTaskExecutor.new(task)
      @Reschedule = opts[:reschedule] || :after
      @RunNow = opts[:now] || opts[:run_now]
    end

    # Create and execute a new `TimerTask2`.
    #
    # @!macro timer_task_initializ
    #
    # @example
    #   task = Concurrent::TimerTask2.execute(execution_interval: 10) { print "Hello World\n" }
    #   task.running? #=> true
    def self.execute(*args, &task)
      self.new(*args, &task).execute
    end

    # Execute a previously created `TimerTask2`.
    #
    # @return [TimerTask2] a reference to `self`
    #
    # @example Instance and execute in separate steps
    #   task = Concurrent::TimerTask2.new(execution_interval: 10) { print "Hello World\n" }
    #   task.running? #=> false
    #   task.execute
    #   task.running? #=> true
    #
    # @example Instance and execute in one line
    #   task = Concurrent::TimerTask2.new(execution_interval: 10) { print "Hello World\n" }.execute
    #   task.running? #=> true
    def execute
      execute?
      self
    end

    def execute?
      return false if running?
      @Cancellation.set(Cancellation.new)
      execute_task cancellation, @RunNow
      true
    end

    def shutdown
      # TODO: Implement soft shutdown
      kill
    end

    def kill
      return false unless running?
      cancellation = @Cancellation.get
      success = @Cancellation.compare_and_set cancellation, nil
      cancellation.origin.resolve if success
      success
    end

    def running?
      cancellation && !cancellation.canceled?
    end

    def cancellation
      @Cancellation.get
    end

    # @!attribute [rw] execution_interval
    # @return [Fixnum] Number of seconds after the task completes before the
    #   task is performed again.
    def execution_interval
      @ExecutionInterval.get
    end

    # @!attribute [rw] execution_interval
    # @return [Fixnum] Number of seconds after the task completes before the
    #   task is performed again.
    def execution_interval=(value)
      if (value = value.to_f) <= 0.0
        raise ArgumentError.new('must be greater than zero')
      else
        @ExecutionInterval.set value
      end
    end

    # @!attribute [rw] timeout_interval
    # @return [Fixnum] Number of seconds the task can run before it is
    #   considered to have failed.
    def timeout_interval
      @TimeoutInterval.get
    end

    # @!attribute [rw] timeout_interval
    # @return [Fixnum] Number of seconds the task can run before it is
    #   considered to have failed.
    def timeout_interval=(value)
      if (value = value.to_f) <= 0.0
        raise ArgumentError.new('must be greater than zero')
      else
        @TimeoutInterval.set value
      end
    end

    private

    def execute_task(cancellation, first_run = false)
      Promises.schedule(first_run ? 0 : execution_interval) do
        with_rescheduling(cancellation) do |cancellation|
          result = @Executor.execute(self, cancellation)
          @Channel.push result if @Channel
        end
      end
    end

    def with_rescheduling(cancellation)
      if cancellation.canceled?
        @Channel.push [false, nil, Concurrent::CancelledOperationError.new]
        return
      end
      execute_task(cancellation) if @Reschedule == :before
      yield Cancellation.timeout(timeout_interval).join(cancellation)
      execute_task(cancellation) if @Reschedule == :after
    end
  end
end

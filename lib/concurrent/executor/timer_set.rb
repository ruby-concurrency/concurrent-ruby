require 'thread'
require 'concurrent/options_parser'
require 'concurrent/atomic/event'
require 'concurrent/collection/priority_queue'
require 'concurrent/executor/executor'
require 'concurrent/executor/single_thread_executor'
require 'concurrent/utility/monotonic_time'

module Concurrent

  # Executes a collection of tasks, each after a given delay. A master task
  # monitors the set and schedules each task for execution at the appropriate
  # time. Tasks are run on the global task pool or on the supplied executor.
  #
  # @!macro monotonic_clock_warning
  class TimerSet
    include RubyExecutor

    # Create a new set of timed tasks.
    #
    # @!macro [attach] executor_options
    #  
    #   @param [Hash] opts the options used to specify the executor on which to perform actions
    #   @option opts [Executor] :executor when set use the given `Executor` instance.
    #     Three special values are also supported: `:task` returns the global task pool,
    #     `:operation` returns the global operation pool, and `:immediate` returns a new
    #     `ImmediateExecutor` object.
    def initialize(opts = {})
      @queue          = PriorityQueue.new(order: :min)
      @task_executor  = OptionsParser::get_task_executor_from(opts)
      @timer_executor = SingleThreadExecutor.new
      @condition      = Condition.new
      init_executor
      enable_at_exit_handler!(opts)
    end

    # Post a task to be execute run after a given delay (in seconds). If the
    # delay is less than 1/100th of a second the task will be immediately post
    # to the executor.
    #
    # @param [Float] delay the number of seconds to wait for before executing the task
    #
    # @yield the task to be performed
    #
    # @return [Boolean] true if the message is post, false after shutdown
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    # @raise [ArgumentError] if no block is given
    #
    # @!macro deprecated_scheduling_by_clock_time
    def post(delay, *args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      delay = TimerSet.calculate_delay!(delay) # raises exceptions

      mutex.synchronize do
        return false unless running?

        if (delay) <= 0.01
          @task_executor.post(*args, &task)
        else
          @queue.push(Task.new(Concurrent.monotonic_time + delay, args, task))
          @timer_executor.post(&method(:process_tasks))
        end
      end

      @condition.signal
      true
    end

    # @!visibility private
    def <<(task)
      post(0.0, &task)
      self
    end

    # For a timer, #kill is like an orderly shutdown, except we need to manually
    # (and destructively) clear the queue first
    def kill
      mutex.synchronize { @queue.clear }
      # possible race condition
      shutdown
    end

    # Schedule a task to be executed after a given delay (in seconds).
    #
    # @param [Float] delay the number of seconds to wait for before executing the task
    #
    # @return [Float] the number of seconds to delay
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    # @raise [ArgumentError] if no block is given
    #
    # @!macro deprecated_scheduling_by_clock_time
    #
    # @!visibility private
    def self.calculate_delay!(delay)
      if delay.is_a?(Time)
        warn '[DEPRECATED] Use an interval not a clock time; schedule is now based on a monotonic clock'
        now = Time.now
        raise ArgumentError.new('schedule time must be in the future') if delay <= now
        delay.to_f - now.to_f
      else
        raise ArgumentError.new('seconds must be greater than zero') if delay.to_f < 0.0
        delay.to_f
      end
    end

    private

    # A struct for encapsulating a task and its intended execution time.
    # It facilitates proper prioritization by overriding the comparison
    # (spaceship) operator as a comparison of the intended execution
    # times.
    #
    # @!visibility private
    Task = Struct.new(:time, :args, :op) do
      include Comparable

      def <=>(other)
        self.time <=> other.time
      end
    end

    private_constant :Task

    # @!visibility private
    def shutdown_execution
      @queue.clear
      @timer_executor.kill
      stopped_event.set
    end

    # Run a loop and execute tasks in the scheduled order and at the approximate
    # scheduled time. If no tasks remain the thread will exit gracefully so that
    # garbage collection can occur. If there are no ready tasks it will sleep
    # for up to 60 seconds waiting for the next scheduled task.
    #
    # @!visibility private
    def process_tasks
      loop do
        task = mutex.synchronize { @queue.peek }
        break unless task

        now = Concurrent.monotonic_time
        diff = task.time - now

        if diff <= 0
          # We need to remove the task from the queue before passing
          # it to the executor, to avoid race conditions where we pass
          # the peek'ed task to the executor and then pop a different
          # one that's been added in the meantime.
          #
          # Note that there's no race condition between the peek and
          # this pop - this pop could retrieve a different task from
          # the peek, but that task would be due to fire now anyway
          # (because @queue is a priority queue, and this thread is
          # the only reader, so whatever timer is at the head of the
          # queue now must have the same pop time, or a closer one, as
          # when we peeked).
          task = mutex.synchronize { @queue.pop }
          @task_executor.post(*task.args, &task.op)
        else
          mutex.synchronize do
            @condition.wait(mutex, [diff, 60].min)
          end
        end
      end
    end
  end
end

require 'thread'
require_relative 'executor'
require 'concurrent/options_parser'
require 'concurrent/atomic/event'
require 'concurrent/collection/priority_queue'
require 'concurrent/executor/single_thread_executor'

module Concurrent

  # Executes a collection of tasks at the specified times. A master thread
  # monitors the set and schedules each task for execution at the appropriate
  # time. Tasks are run on the global task pool or on the supplied executor.
  class TimerSet
    include Executor

    # Create a new set of timed tasks.
    #
    # @param [Hash] opts the options controlling how the future will be processed
    # @option opts [Boolean] :operation (false) when `true` will execute the future on the global
    #   operation pool (for long-running operations), when `false` will execute the future on the
    #   global task pool (for short-running tasks)
    # @option opts [object] :executor when provided will run all operations on
    #   this executor rather than the global thread pool (overrides :operation)
    def initialize(opts = {})
      @queue = PriorityQueue.new(order: :min)
      @task_executor = OptionsParser::get_executor_from(opts)
      @timer_executor = SingleThreadExecutor.new
      @condition = Condition.new
      init_executor
    end

    # Post a task to be execute at the specified time. The given time may be either
    # a `Time` object or the number of seconds to wait. If the intended execution
    # time is within 1/100th of a second of the current time the task will be
    # immediately post to the executor.
    #
    # @param [Object] intended_time the time to schedule the task for execution
    #
    # @yield the task to be performed
    #
    # @return [Boolean] true if the message is post, false after shutdown
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    # @raise [ArgumentError] if no block is given
    def post(intended_time, *args, &task)
      time = TimerSet.calculate_schedule_time(intended_time).to_f
      raise ArgumentError.new('no block given') unless block_given?

      mutex.synchronize do
        return false unless running?

        if (time - Time.now.to_f) <= 0.01
          @task_executor.post(*args, &task)
        else
          @queue.push(Task.new(time, args, task))
          @timer_executor.post(&method(:process_tasks))
        end

        true
      end

    end

    alias_method :kill, :shutdown

    # Calculate an Epoch time with milliseconds at which to execute a
    # task. If the given time is a `Time` object it will be converted
    # accordingly. If the time is an integer value greater than zero
    # it will be understood as a number of seconds in the future and
    # will be added to the current time to calculate Epoch.
    #
    # @param [Object] intended_time the time (as a `Time` object or an integer)
    #   to schedule the task for execution
    # @param [Time] now (Time.now) the time from which to calculate an interval
    #
    # @return [Fixnum] the intended time as seconds/millis from Epoch
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    def self.calculate_schedule_time(intended_time, now = Time.now)
      if intended_time.is_a?(Time)
        raise ArgumentError.new('schedule time must be in the future') if intended_time <= now
        intended_time
      else
        raise ArgumentError.new('seconds must be greater than zero') if intended_time.to_f < 0.0
        now + intended_time
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
        break if @queue.empty?

        task = @queue.peek
        interval = task.time - Time.now.to_f

        if interval <= 0
          @task_executor.post(*task.args, &task.op)
          @queue.pop
        else
          mutex.synchronize do
            @condition.wait(mutex, [interval, 60].min)
          end
        end
      end
    end
  end
end

require 'thread'
require 'concurrent/options_parser'
require 'concurrent/atomic/event'
require 'concurrent/collection/priority_queue'

module Concurrent

  # Executes a collection of tasks at the specified times. A master thread
  # monitors the set and schedules each task for execution at the appropriate
  # time. Tasks are run on the global task pool or on the supplied executor.
  class TimerSet
    include OptionsParser

    # Create a new set of timed tasks.
    #
    # @param [Hash] opts the options controlling how the future will be processed
    # @option opts [Boolean] :operation (false) when `true` will execute the future on the global
    #   operation pool (for long-running operations), when `false` will execute the future on the
    #   global task pool (for short-running tasks)
    # @option opts [object] :executor when provided will run all operations on
    #   this executor rather than the global thread pool (overrides :operation)
    def initialize(opts = {})
      @mutex = Mutex.new
      @shutdown = Event.new
      @queue = PriorityQueue.new(order: :min)
      @executor = get_executor_from(opts)
      @thread = nil
    end

    # Am I running?
    #
    # @return [Boolean] `true` when running, `false` when shutting down or shutdown
    def running?
      ! @shutdown.set?
    end

    # Am I shutdown?
    #
    # @return [Boolean] `true` when shutdown, `false` when shutting down or running
    def shutdown?
      @shutdown.set?
    end

    # Block until shutdown is complete or until `timeout` seconds have passed.
    #
    # @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] `true` if shutdown complete or false on `timeout`
    def wait_for_termination(timeout)
      @shutdown.wait(timeout.to_f)
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
    def post(intended_time, &block)
      @mutex.synchronize do
        return false if shutdown?
        raise ArgumentError.new('no block given') unless block_given?
        time = calculate_schedule_time(intended_time)

        if (time - Time.now.to_f) <= 0.01
          @executor.post(&block)
        else
          @queue.push(Task.new(time, block))
        end
      end
      check_processing_thread!
      true
    end

    def shutdown
      @mutex.synchronize do
        unless @shutdown.set?
          @queue.clear
          @thread.kill if @thread
          @shutdown.set
        end
      end
      true
    end
    alias_method :kill, :shutdown

    private

    # A struct for encapsulating a task and its intended execution time.
    # It facilitates proper prioritization by overriding the comparison
    # (spaceship) operator as a comparison of the intended execution
    # times.
    #
    # @!visibility private
    Task = Struct.new(:time, :op) do
      include Comparable
      def <=>(other)
        self.time <=> other.time
      end
    end

    # Calculate an Epoch time with milliseconds at which to execute a
    # task. If the given time is a `Time` object it will be converted
    # accordingly. If the time is an integer value greate than zero
    # it will be understood as a number of seconds in the future and
    # will be added to the current time to calculate Epoch.
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    #
    # @!visibility private
    def calculate_schedule_time(intended_time, now = Time.now)
      if intended_time.is_a?(Time)
        raise ArgumentError.new('schedule time must be in the future') if intended_time <= now
        intended_time.to_f
      else
        raise ArgumentError.new('seconds must be greater than zero') if intended_time.to_f < 0.0
        now.to_f + intended_time.to_f
      end
    end

    # Check the status of the processing thread. This thread is responsible
    # for monitoring the internal task queue and sending tasks to the
    # executor when it is time for them to be processed. If there is no
    # processing thread one will be created. If the processing thread is
    # sleeping it will be worken up. If the processing thread has died it
    # will be garbage collected and a new one will be created.
    #
    # @!visibility private
    def check_processing_thread!
      @mutex.synchronize do
        return if shutdown? || @queue.empty?
        if @thread && @thread.status == 'sleep'
          @thread.wakeup
        elsif @thread.nil? || ! @thread.alive?
          @thread = Thread.new do
            Thread.current.abort_on_exception = true
            process_tasks
          end
        end
      end
    end

    # Check the head of the internal task queue for a ready task.
    #
    # @return [Task] the next task to be executed or nil if none are ready
    #
    # @!visibility private
    def next_task
      @mutex.synchronize do
        unless @queue.empty? || @queue.peek.time > Time.now.to_f
          @queue.pop
        else
          nil
        end
      end
    end

    # Calculate the time difference, in seconds and milliseconds, between
    # now and the intended execution time of the next task to be ececuted.
    #
    # @return [Integer] the number of seconds and milliseconds to sleep
    #   or nil if the task queue is empty
    #
    # @!visibility private
    def next_sleep_interval
      @mutex.synchronize do
        if @queue.empty?
          nil
        else
          @queue.peek.time - Time.now.to_f
        end
      end
    end

    # Run a loop and execute tasks in the scheduled order and at the approximate
    # shceduled time. If no tasks remain the thread will exit gracefully so that
    # garbage collection can occur. If there are no ready tasks it will sleep
    # for up to 60 seconds waiting for the next scheduled task.
    #
    # @!visibility private
    def process_tasks
      loop do
        while task = next_task do
          @executor.post(&task.op)
        end
        if (interval = next_sleep_interval).nil?
          break
        else
          sleep([interval, 60].min)
        end
      end
    end
  end
end

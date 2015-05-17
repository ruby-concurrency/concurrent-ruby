require 'concurrent/errors'
require 'concurrent/ivar'
require 'concurrent/atomic/event'
require 'concurrent/collection/priority_queue'
require 'concurrent/executor/executor'
require 'concurrent/executor/executor_service'
require 'concurrent/executor/single_thread_executor'
require 'concurrent/utility/monotonic_time'

module Concurrent

  # Executes a collection of tasks, each after a given delay. A master task
  # monitors the set and schedules each task for execution at the appropriate
  # time. Tasks are run on the global task pool or on the supplied executor.
  #
  # @!macro monotonic_clock_warning
  class TimerSet < RubyExecutorService

    # An `IVar` representing a tasked queued for execution in a `TimerSet`.
    class Task < Concurrent::IVar
      include Comparable

      def initialize(parent, delay, args, task, opts = {})
        super(IVar::NO_VALUE, opts, &nil)
        synchronize do
          ns_set_delay_and_time!(delay)
          @parent = parent
          @args = args
          @task = task
          self.observers = CopyOnNotifyObserverSet.new
        end
      end

      def original_delay
        synchronize { @delay }
      end

      def schedule_time
        synchronize { @time }
      end

      def <=>(other)
        self.schedule_time <=> other.schedule_time
      end

      # Has the task been cancelled?
      #
      # @return [Boolean] true if the task is in the given state else false
      def cancelled?
        synchronize { ns_check_state?(:cancelled) }
      end

      # In the task execution in progress?
      #
      # @return [Boolean] true if the task is in the given state else false
      def processing?
        synchronize { ns_check_state?(:processing) }
      end

      # Cancel this task and prevent it from executing. A task can only be
      # cancelled if it is pending or unscheduled.
      #
      # @return [Boolean] true if task execution is successfully cancelled
      #   else false
      def cancel
        if compare_and_set_state(:cancelled, :pending, :unscheduled)
          complete(false, nil, CancelledOperationError.new)
          # To avoid deadlocks this call must occur outside of #synchronize
          # Changing the state above should prevent redundant calls
          @parent.send(:remove_task, self)
        else
          false
        end
      end

      def reset
        synchronize{ ns_reschedule(@delay) }
      end

      def reschedule(delay)
        synchronize{ ns_reschedule(delay) }
      end

      # @!visibility private
      def process_task
        safe_execute(@task, @args)
      end

      protected :set, :try_set, :fail, :complete

      protected

      def ns_set_delay_and_time!(delay)
        @delay = TimerSet.calculate_delay!(delay)
        @time = Concurrent.monotonic_time + @delay
      end

      def ns_reschedule(delay, fail_if_cannot_remove = true)
        return false unless ns_check_state?(:pending)
        ns_set_delay_and_time!(delay)
        removed = @parent.send(:remove_task, self)
        return false if fail_if_cannot_remove && !removed
        @parent.send(:post_task, self)
      end
    end

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
      super(opts)
    end

    # Post a task to be execute run after a given delay (in seconds). If the
    # delay is less than 1/100th of a second the task will be immediately post
    # to the executor.
    #
    # @param [Float] delay the number of seconds to wait for before executing the task
    #
    # @yield the task to be performed
    #
    # @return [Concurrent::TimerSet::Task, false] IVar representing the task if the post
    #   is successful; false after shutdown
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    # @raise [ArgumentError] if no block is given
    #
    # @!macro deprecated_scheduling_by_clock_time
    def post(delay, *args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      task = Task.new(self, delay, args, task) # may raise exception
      ok = synchronize{ ns_post_task(task) }
      ok ? task : false
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
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

    private :<<

    protected

    # @!visibility private
    def ns_initialize(opts)
      @queue          = PriorityQueue.new(order: :min)
      @task_executor  = Executor.executor_from_options(opts) || Concurrent.global_io_executor
      @timer_executor = SingleThreadExecutor.new
      @condition      = Event.new
      self.auto_terminate = opts.fetch(:auto_terminate, true)
    end

    def post_task(task)
      synchronize{ ns_post_task(task) }
    end

    # @!visibility private
    def ns_post_task(task)
      return false unless ns_running?
      if (task.original_delay) <= 0.01
        @task_executor.post{ task.process_task }
      else
        @queue.push(task)
        # only post the process method when the queue is empty
        @timer_executor.post(&method(:process_tasks)) if @queue.length == 1
        @condition.set
      end
      true
    end

    # Remove the given task from the queue.
    #
    # @note This is intended as a callback method from Task only.
    #   It is not intended to be used directly. Cancel a task by
    #   using the `Task#cancel` method.
    #
    # @!visibility private
    def remove_task(task)
      synchronize{ @queue.delete(task) }
    end

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
        task = synchronize { @condition.reset; @queue.peek }
        break unless task

        now = Concurrent.monotonic_time
        diff = task.schedule_time - now

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
          task = synchronize { @queue.pop }
          @task_executor.post{ task.process_task }
        else
          @condition.wait([diff, 60].min)
        end
      end
    end
  end
end

require 'concurrent/concern/logging'

module Concurrent

  ###################################################################

  # @!macro [new] executor_service_method_post
  #
  #   Submit a task to the executor for asynchronous processing.
  #
  #   @param [Array] args zero or more arguments to be passed to the task
  #
  #   @yield the asynchronous task to perform
  #
  #   @return [Boolean] `true` if the task is queued, `false` if the executor
  #     is not running
  #
  #   @raise [ArgumentError] if no task is given

  # @!macro [new] executor_service_method_prioritize
  #
  #   Submit a prioritized task to the executor for asynchronous processing.
  #   Tasks will be enqueued in priority order so that tasks with higher
  #   priority will be executed before tasks with a lower priority.
  #
  #   If the queue is empty when a task is post or the pool is capable of
  #   adding additional threads then prioritization is irrelevant. Tasks
  #   will be passed to a thread for execution as soon as they are post. When
  #   the pool is unable to add more threads due to configuration constraints
  #   and tasks are backing up in the queue then prioritization is important.
  #   In this situation, tasks with a higher priority will move ahead of tasks
  #   with a lower priority in the queue.
  #
  #   The order in which tasks of the same priority are enqueued with respect
  #   to one another is undefined.
  #
  #   The executor must be configured for prioritization when it is created
  #   otherwise the `priority` argument is ignored. In that case this
  #   method becomes the equivalent or the `#post` method.
  #
  #   When an executor is configured for prioritization the `#post` method
  #   posts its tasks with a priority of zero.
  #
  #   @param [Fixnum] priority the relative priority of this task with respect
  #     to all other tasks in the queue
  #   @param [Array] args zero or more arguments to be passed to the task
  #
  #   @yield the asynchronous task to perform
  #
  #   @return [Boolean] `true` if the task is queued, `false` if the executor
  #     is not running
  #
  #   @raise [ArgumentError] if no task is given

  # @!macro [new] executor_service_method_left_shift
  #
  #   Submit a task to the executor for asynchronous processing.
  #
  #   @param [Proc] task the asynchronous task to perform
  #
  #   @return [self] returns itself

  # @!macro [new] executor_service_method_can_overflow_question
  #
  #   Does the task queue have a maximum size?
  #
  #   @return [Boolean] True if the task queue has a maximum size else false.

  # @!macro [new] executor_service_method_serialized_question
  #
  #   Does this executor guarantee serialization of its operations?
  #
  #   @return [Boolean] True if the executor guarantees that all operations
  #     will be post in the order they are received and no two operations may
  #     occur simultaneously. Else false.

  # @!macro [new] executor_service_method_prioritized_question
  #
  #   Does this executor allow tasks to be ordered based on a given priority?
  #
  #   @return [Boolean] True if the executor provides the caller the ability
  #     to influence the prioritization of operations post to it. Else false.

  ###################################################################

  # @!macro [new] executor_service_public_api
  #
  #   @!method post(*args, &task)
  #     @!macro executor_service_method_post
  #
  #   @!method <<(task)
  #     @!macro executor_service_method_left_shift
  #
  #   @!method can_overflow?
  #     @!macro executor_service_method_can_overflow_question
  #
  #   @!method serialized?
  #     @!macro executor_service_method_serialized_question
  #
  #   @!method prioritized?
  #     @!macro executor_service_method_prioritized_question

  ###################################################################

  # @!macro [new] executor_service_method_shutdown
  #
  #   Begin an orderly shutdown. Tasks already in the queue will be executed,
  #   but no new tasks will be accepted. Has no additional effect if the
  #   thread pool is not running.

  # @!macro [new] executor_service_method_kill
  #
  #   Begin an immediate shutdown. In-progress tasks will be allowed to
  #   complete but enqueued tasks will be dismissed and no new tasks
  #   will be accepted. Has no additional effect if the thread pool is
  #   not running.

  # @!macro [new] executor_service_method_wait_for_termination
  #
  #   Block until executor shutdown is complete or until `timeout` seconds have
  #   passed.
  #
  #   @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
  #     must be called before this method (or on another thread).
  #
  #   @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
  #
  #   @return [Boolean] `true` if shutdown complete or false on `timeout`

  # @!macro [new] executor_service_method_running_question
  #
  #   Is the executor running?
  #
  #   @return [Boolean] `true` when running, `false` when shutting down or shutdown

  # @!macro [new] executor_service_method_shuttingdown_question
  #
  #   Is the executor shuttingdown?
  #
  #   @return [Boolean] `true` when not running and not shutdown, else `false`

  # @!macro [new] executor_service_method_shutdown_question
  #
  #   Is the executor shutdown?
  #
  #   @return [Boolean] `true` when shutdown, `false` when shutting down or running

  # @!macro [new] executor_service_method_auto_terminate_question
  #
  #   Is the executor auto-terminate when the application exits?
  #
  #   @return [Boolean] `true` when auto-termination is enabled else `false`.

  # @!macro [new] executor_service_method_auto_terminate_setter
  #
  #   Set the auto-terminate behavior for this executor.
  #
  #   @param [Boolean] value The new auto-terminate value to set for this executor.
  #
  #   @return [Boolean] `true` when auto-termination is enabled else `false`.

  ###################################################################

  # @!macro [new] abstract_executor_service_public_api
  #
  #   @!macro executor_service_public_api
  #
  #   @!method shutdown
  #     @!macro executor_service_method_shutdown
  #
  #   @!method kill
  #     @!macro executor_service_method_kill
  #
  #   @!method wait_for_termination(timeout = nil)
  #     @!macro executor_service_method_wait_for_termination
  #
  #   @!method running?
  #     @!macro executor_service_method_running_question
  #
  #   @!method shuttingdown?
  #     @!macro executor_service_method_shuttingdown_question
  #
  #   @!method shutdown?
  #     @!macro executor_service_method_shutdown_question
  #
  #   @!method auto_terminate?
  #     @!macro executor_service_method_auto_terminate_question
  #
  #   @!method auto_terminate=(value)
  #     @!macro executor_service_method_auto_terminate_setter

  ###################################################################

  # @!macro executor_service_public_api
  # @!visibility private
  module ExecutorService
    include Concern::Logging

    # @!macro executor_service_method_post
    def post(*args, &task)
      raise NotImplementedError
    end

    # @!macro executor_service_method_left_shift
    def <<(task)
      post(&task)
      self
    end

    # @!macro executor_service_method_can_overflow_question
    #
    # @note Always returns `false`
    def can_overflow?
      false
    end

    # @!macro executor_service_method_serialized_question
    #
    # @note Always returns `false`
    def serialized?
      false
    end

    # @!macro executor_service_method_prioritized_question
    #
    # @note Always returns `false`
    def prioritized?
      false
    end
  end
end

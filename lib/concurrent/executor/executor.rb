require 'concurrent/errors'
require 'concurrent/logging'
require 'concurrent/at_exit'
require 'concurrent/atomic/event'

module Concurrent

  module Executor
    include Logging

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @param [Hash] opts the options defining the requested executor
    # @option opts [Executor] :executor when set use the given `Executor` instance.
    #   Three special values are also supported: `:fast` returns the global fast executor,
    #   `:io` returns the global io executor, and `:immediate` returns a new
    #   `ImmediateExecutor` object.
    #
    # @return [Executor, nil] the requested thread pool, or nil when no option specified
    #
    # @!visibility private
    def self.executor_from_options(opts = {}) # :nodoc:
      case
      when opts.key?(:executor)
        if opts[:executor].nil?
          nil
        else
          executor(opts[:executor])
        end
      when opts.key?(:operation) || opts.key?(:task)
        if opts[:operation] == true || opts[:task] == false
          Kernel.warn '[DEPRECATED] use `executor: :fast` instead'
          return Concurrent.global_fast_executor
        end

        if opts[:operation] == false || opts[:task] == true
          Kernel.warn '[DEPRECATED] use `executor: :io` instead'
          return Concurrent.global_io_executor
        end

        raise ArgumentError.new("executor '#{opts[:executor]}' not recognized")
      else
        nil
      end
    end

    def self.executor(executor_identifier)
      case executor_identifier
      when :fast
        Concurrent.global_fast_executor
      when :io
        Concurrent.global_io_executor
      when :immediate
        Concurrent.global_immediate_executor
      when :operation
        Kernel.warn '[DEPRECATED] use `executor: :fast` instead'
        Concurrent.global_fast_executor
      when :task
        Kernel.warn '[DEPRECATED] use `executor: :io` instead'
        Concurrent.global_io_executor
      when Executor
        executor_identifier
      else
        raise ArgumentError, "executor not recognized by '#{executor_identifier}'"
      end
    end

    # @!macro [attach] executor_method_post
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
    def post(*args, &task)
      raise NotImplementedError
    end

    # @!macro [attach] executor_method_left_shift
    #
    #   Submit a task to the executor for asynchronous processing.
    #
    #   @param [Proc] task the asynchronous task to perform
    #
    #   @return [self] returns itself
    def <<(task)
      post(&task)
      self
    end

    # @!macro [attach] executor_module_method_can_overflow_question
    #
    #   Does the task queue have a maximum size?
    #
    #   @return [Boolean] True if the task queue has a maximum size else false.
    #
    # @note Always returns `false`
    def can_overflow?
      false
    end

    # @!macro [attach] executor_module_method_serialized_question
    #
    #   Does this executor guarantee serialization of its operations?
    #
    #   @return [Boolean] True if the executor guarantees that all operations
    #     will be post in the order they are received and no two operations may
    #     occur simultaneously. Else false.
    #
    # @note Always returns `false`
    def serialized?
      false
    end
  end

  # Indicates that the including `Executor` or `ExecutorService` guarantees
  # that all operations will occur in the order they are post and that no
  # two operations may occur simultaneously. This module provides no
  # functionality and provides no guarantees. That is the responsibility
  # of the including class. This module exists solely to allow the including
  # object to be interrogated for its serialization status.
  #
  # @example
  #   class Foo
  #     include Concurrent::SerialExecutor
  #   end
  #
  #   foo = Foo.new
  #
  #   foo.is_a? Concurrent::Executor       #=> true
  #   foo.is_a? Concurrent::SerialExecutor #=> true
  #   foo.serialized?                      #=> true
  module SerialExecutor
    include Executor

    # @!macro executor_module_method_serialized_question
    #
    # @note Always returns `true`
    def serialized?
      true
    end
  end
end

require 'concurrent/configuration'
require 'concurrent/executor/immediate_executor'

module Concurrent

  # A mixin module for parsing options hashes related to gem-level configuration.
  module OptionsParser

    # @!visibility private
    def get_arguments_from(opts = {}) # :nodoc:
      [*opts.fetch(:args, [])]
    end

    # @!macro [attach] get_executor_from
    #
    #   Get the requested `Executor` based on the values set in the options hash.
    #  
    #   @param [Hash] opts the options defining the requested executor
    #   @option opts [Executor] :executor when set use the given `Executor` instance.
    #     Three special values are also supported: `:task` returns the global task pool,
    #     `:operation` returns the global operation pool, and `:immediate` returns a new
    #     `ImmediateExecutor` object.
    #
    # @return [Executor, nil] the requested thread pool, or nil when no option specified
    #
    # @!visibility private
    def get_executor_from(opts = {}) # :nodoc:
      if (executor = opts[:executor]).is_a? Symbol
        case opts[:executor]
        when :task
          Concurrent.configuration.global_task_pool
        when :operation
          Concurrent.configuration.global_operation_pool
        when :immediate
          Concurrent::ImmediateExecutor.new
        else
          raise ArgumentError.new("executor '#{executor}' not recognized")
        end
      elsif opts[:executor]
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Kernel.warn '[DEPRECATED] use `executor: :operation` instead'
        Concurrent.configuration.global_operation_pool
      elsif opts[:operation] == false || opts[:task] == true
        Kernel.warn '[DEPRECATED] use `executor: :task` instead'
        Concurrent.configuration.global_task_pool
      else
        nil
      end
    end

    # @!macro get_executor_from
    #
    # @return [Executor] the requested thread pool (default: global task pool)
    #
    # @!visibility private
    def get_task_executor_from(opts = {}) # :nodoc:
      get_executor_from(opts) || Concurrent.configuration.global_task_pool
    end

    # @!macro get_executor_from
    #
    # @return [Executor] the requested thread pool (default: global operation pool)
    #
    # @!visibility private
    def get_operation_executor_from(opts = {}) # :nodoc:
      get_executor_from(opts) || Concurrent.configuration.global_operation_pool
    end

    extend self
  end
end

module Concurrent

  # A mixin module for parsing options hashes related to gem-level configuration.
  module OptionsParser

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @param [Hash] opts the options defining the requested executor
    # @option opts [Executor] :executor (`nil`) when set use the given `Executor` instance
    # @option opts [Boolean] :operation (`false`) when true use the global operation pool
    # @option opts [Boolean] :task (`true`) when true use the global task pool
    #
    # @return [Executor, nil] the requested thread pool, or nil when no option specified
    def get_executor_from(opts = {})
      if opts[:executor]
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Concurrent.configuration.global_operation_pool
      elsif opts[:operation] == false || opts[:task] == true
        Concurrent.configuration.global_task_pool
      else
        nil
      end
    end

    def get_arguments_from(opts = {})
      [*opts.fetch(:args, [])]
    end

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @param [Hash] opts the options defining the requested executor
    # @option opts [Executor] :task_executor (`nil`) when set use the given `Executor` instance
    #
    # @return [Executor] the requested thread pool (default: global task pool)
    def get_task_executor_from(opts = {})
      opts[:task_executor] || opts[:executor] || Concurrent.configuration.global_task_pool
    end

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @param [Hash] opts the options defining the requested executor
    # @option opts [Executor] :task_executor (`nil`) when set use the given `Executor` instance
    #
    # @return [Executor] the requested thread pool (default: global operation pool)
    def get_operation_executor_from(opts = {})
      opts[:operation_executor] || opts[:executor] || Concurrent.configuration.global_operation_pool
    end

    extend self
  end
end

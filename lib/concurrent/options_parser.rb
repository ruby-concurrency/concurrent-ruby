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
    # @return [Executor] the requested thread pool (default: global task pool)
    def get_executor_from(opts = {})
      if opts[:executor]
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Concurrent.configuration.global_operation_pool
      else
        Concurrent.configuration.global_task_pool
      end
    end
  end
end

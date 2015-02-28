require 'concurrent/configuration'
require 'concurrent/executor/immediate_executor'

module Concurrent

  # A mixin module for parsing options hashes related to gem-level configuration.
  module OptionsParser

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
    def get_executor_from(opts = {}) # :nodoc:
      if (executor = opts[:executor]).is_a? Symbol
        case opts[:executor]
        when :fast
          Concurrent.global_fast_executor
        when :io
          Concurrent.global_io_executor
        when :immediate
          Concurrent::ImmediateExecutor.new
        when :operation
          Kernel.warn '[DEPRECATED] use `executor: :fast` instead'
          Concurrent.global_fast_executor
        when :task
          Kernel.warn '[DEPRECATED] use `executor: :io` instead'
          Concurrent.global_io_executor
        else
          raise ArgumentError.new("executor '#{executor}' not recognized")
        end
      elsif opts[:executor]
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Kernel.warn '[DEPRECATED] use `executor: :fast` instead'
        Concurrent.global_fast_executor
      elsif opts[:operation] == false || opts[:task] == true
        Kernel.warn '[DEPRECATED] use `executor: :io` instead'
        Concurrent.global_io_executor
      else
        nil
      end
    end
  end
end

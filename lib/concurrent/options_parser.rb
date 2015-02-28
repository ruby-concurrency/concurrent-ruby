require 'concurrent/configuration'
require 'concurrent/executor/immediate_executor'

module Concurrent

  # A mixin module for parsing options hashes related to gem-level configuration.
  module OptionsParser
    extend self

    # @!visibility private
    def get_arguments_from(opts = {}) # :nodoc:
      [*opts.fetch(:args, [])]
    end

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @!macro [attach] get_executor_from
    #  
    #   @param [Hash] opts the options defining the requested executor
    #   @option opts [Executor] :executor when set use the given `Executor` instance.
    #     Three special values are also supported: `:fast` returns the global fast executor,
    #     `:io` returns the global io executor, and `:immediate` returns a new
    #     `ImmediateExecutor` object.
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

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @!macro get_executor_from
    #
    # @return [Executor] the requested thread pool (default: global fast executor)
    #
    # @!visibility private
    def get_fast_executor_from(opts = {}) # :nodoc:
      get_executor_from(opts) || Concurrent.global_fast_executor
    end

    # @deprecated
    # @!visibility private
    def get_operation_executor_from(opts = {}) # :nodoc:
      warn '[DEPRECATED] Use OptionsParser.get_fast_executor_from instead'
      get_fast_executor_from(opts)
    end

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @!macro get_executor_from
    #
    # @return [Executor] the requested thread pool (default: global io executor)
    #
    # @!visibility private
    def get_io_executor_from(opts = {}) # :nodoc:
      get_executor_from(opts) || Concurrent.global_io_executor
    end

    # @deprecated
    # @!visibility private
    def get_task_executor_from(opts = {}) # :nodoc:
      warn '[DEPRECATED] Use OptionsParser.get_io_executor_from instead'
      get_io_executor_from(opts)
    end
  end
end

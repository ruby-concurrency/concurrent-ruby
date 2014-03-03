require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/safe_task_executor'

module Concurrent

  class Future < IVar
    include UsesGlobalThreadPool

    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      super(IVar::NO_VALUE, opts)
      @state = :unscheduled
      @task = block
    end

    # @since 0.5.0
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        Future.thread_pool.post { work }
        self
      end
    end

    # @since 0.5.0
    def self.execute(opts = {}, &block)
      return Future.new(opts, &block).execute
    end

    private

    # @!visibility private
    def work # :nodoc:
      success, val, reason = SafeTaskExecutor.new(@task).execute
      complete(val, reason)
    end

  end
end

require 'concurrent/configuration'

module Concurrent

  module UsesGlobalThreadPool

    def self.included(base)
      class << base
        def thread_pool
          @thread_pool || Concurrent.configuration.global_task_pool
        end
        def thread_pool=(pool)
          if pool == Concurrent.configuration.global_task_pool
            @thread_pool = nil
          else
            @thread_pool = pool
          end
        end
      end
    end

    protected

    def operation?(opts = {})
      opts[:operation] == true || opts[:task] == false
    end

    def task?(opts = {})
      ! operation?(opts)
    end
  end
end

require 'concurrent/configuration'

module Concurrent

  module UsesGlobalThreadPool

    def self.included(base)
      class << base
        def thread_pool
          @thread_pool || Concurrent.configuration.global_thread_pool
        end
        def thread_pool=(pool)
          if pool == Concurrent.configuration.global_thread_pool
            @thread_pool = nil
          else
            @thread_pool = pool
          end
        end
      end
    end
  end
end

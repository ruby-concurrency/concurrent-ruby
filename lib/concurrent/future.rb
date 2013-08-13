require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/utilities'

module Concurrent

  class Future
    include Obligation
    include UsesGlobalThreadPool

    behavior(:future)

    def initialize(*args, &block)
      unless block_given?
        @state = :fulfilled
      else
        @value = nil
        @state = :pending
        Future.thread_pool.post(*args) do
          Thread.pass
          work(*args, &block)
        end
      end
    end

    private

    # @private
    def work(*args) # :nodoc:
      mutex.synchronize do
        begin
          @value = yield(*args)
          @state = :fulfilled
        rescue Exception => ex
          @state = :rejected
          @reason = ex
        end
      end
    end
  end
end

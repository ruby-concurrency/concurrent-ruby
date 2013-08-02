require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/utilities'

module Concurrent

  class Future
    include Obligation
    behavior(:future)

    def initialize(*args, &block)
      if args.first.behaves_as?(:global_thread_pool)
        thread_pool = args.first
        args = args.slice(1, args.length)
      else
        thread_pool = $GLOBAL_THREAD_POOL
      end

      unless block_given?
        @state = :fulfilled
      else
        @value = nil
        @state = :pending
        thread_pool.post do
          Thread.pass
          work(*args, &block)
        end
      end
    end

    private

    # @private
    def work(*args) # :nodoc:
      semaphore.synchronize do
        begin
          atomic {
            @value = yield(*args)
            @state = :fulfilled
          }
        rescue Exception => ex
          atomic {
            @state = :rejected
            @reason = ex
          }
        end
      end
    end
  end
end

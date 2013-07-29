require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/utilities'

module Concurrent

  class Future
    include Obligation
    behavior(:future)

    def initialize(*args, &block)

      unless block_given?
        @state = :fulfilled
      else
        @value = nil
        @state = :pending
        $GLOBAL_THREAD_POOL.post do
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

module Kernel

  def future(*args, &block)
    return Concurrent::Future.new(*args, &block)
  end
  module_function :future
end

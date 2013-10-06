require 'thread'
require 'observer'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/utilities'

module Concurrent

  class Future
    include Obligation
    include Observable
    include UsesGlobalThreadPool

    behavior(:future)

    def initialize(*args, &block)
      unless block_given?
        @state = :fulfilled
      else
        @value = nil
        @state = :pending
        Future.thread_pool.post(*args) do
          work(*args, &block)
        end
      end
    end

    private

    # @private
    def work(*args) # :nodoc:
      begin
        @value = yield(*args)
        @state = :fulfilled
      rescue Exception => ex
        @reason = ex
        @state = :rejected
      ensure
        event.set
        changed
        notify_observers(Time.now, @value, @reason)
      end
    end
  end
end

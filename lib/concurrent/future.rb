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
      @mutex = Mutex.new
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

    def add_observer(observer, func = :update)
      @mutex.synchronize do
        if event.set?
          Future.thread_pool.post(func, Time.now, @value, @reason) do |f, *args|
            observer.send(f, *args)
          end
        else
          super
        end
      end
      return func
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
        @mutex.synchronize {
          event.set
          changed
          notify_observers(Time.now, @value, @reason)
          delete_observers
        }
      end
    end
  end
end

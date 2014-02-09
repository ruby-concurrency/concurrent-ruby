require 'thread'
require 'observer'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'

module Concurrent

  class Future
    include Obligation
    include Observable
    include UsesGlobalThreadPool

    def initialize(&block)
      if ! block_given?
        raise ArgumentError.new('no block given')
      else
        init_mutex
        @state = :unscheduled
        @task = block
      end
    end

    # Is the future still unscheduled?
    # @return [Boolean]
    def unscheduled?() return(@state == :unscheduled); end

    def add_observer(observer, func = :update)
      val = self.value
      mutex.synchronize do
        if event.set?
          Future.thread_pool.post(func, Time.now, val, @reason) do |f, *args|
            observer.send(f, *args)
          end
        else
          super
        end
      end
      return func
    end

    def execute
      mutex.synchronize do
        return unless @state == :unscheduled
        @state = :pending
      end
      Future.thread_pool.post do
        work(&@task)
      end
      return self
    end

    def self.execute(&block)
      return Future.new(&block).execute
    end

    private

    # @private
    def work # :nodoc:
      begin
        @value = yield
        @state = :fulfilled
      rescue Exception => ex
        @reason = ex
        @state = :rejected
      ensure
        val = self.value
        mutex.synchronize do
          event.set
          changed
          notify_observers(Time.now, val, @reason)
          delete_observers
        end
      end
    end
  end
end

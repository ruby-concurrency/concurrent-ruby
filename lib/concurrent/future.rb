require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/copy_on_write_observer_set'

module Concurrent

  class Future
    include Obligation
    include UsesGlobalThreadPool

    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_mutex
      @observers = CopyOnWriteObserverSet.new
      @state = :unscheduled
      @task = block
      set_deref_options(opts)
    end

    # Is the future still unscheduled?
    # @return [Boolean]
    def unscheduled?() state == :unscheduled; end

    def add_observer(observer, func = :update)
      val = self.value
      mutex.synchronize do
        if event.set?
          Future.thread_pool.post(func, Time.now, val, @reason) do |f, *args|
            observer.send(f, *args)
          end
        else
          @observers.add_observer(observer, func)
        end
      end
      func
    end

    def execute
      mutex.synchronize do
        return unless @state == :unscheduled
        @state = :pending
      end
      Future.thread_pool.post do
        work(&@task)
      end
      self
    end

    def self.execute(opts = {}, &block)
      return Future.new(opts, &block).execute
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
          @observers.notify_and_delete_observers(Time.now, val, @reason)
        end
      end
    end
  end
end

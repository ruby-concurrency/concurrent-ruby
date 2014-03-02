require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/copy_on_write_observer_set'
require 'concurrent/safe_task_executor'

module Concurrent

  class Future
    include Obligation
    include UsesGlobalThreadPool

    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_obligation
      @observers = CopyOnWriteObserverSet.new
      @state = :unscheduled
      @task = block
      set_deref_options(opts)
    end

    def add_observer(observer, func = :update)
      direct_notification = false
      mutex.synchronize do
        if event.set?
          direct_notification = true
        else
          @observers.add_observer(observer, func)
        end
      end

      observer.send(func, Time.now, self.value, reason) if direct_notification
      func
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

      mutex.synchronize do
        set_state(success, val, reason)
        event.set
      end

      @observers.notify_and_delete_observers(Time.now, self.value, reason)
    end

  end
end

require 'thread'

require 'concurrent/obligation'
require 'concurrent/copy_on_write_observer_set'

module Concurrent

  class IVar
    include Obligation

    NO_VALUE = Object.new

    def initialize(value = NO_VALUE, opts = {})
      init_obligation
      @observers = CopyOnWriteObserverSet.new
      set_deref_options(opts)

      if value == NO_VALUE
        @state = :pending
      else
        set(value)
      end
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

    def set(value)
      complete(value, nil)
    end

    def complete(value, reason)
      mutex.synchronize do
        set_state(reason.nil?, value, reason)
        event.set
      end

      @observers.notify_and_delete_observers(Time.now, self.value, reason)
    end

  end
end

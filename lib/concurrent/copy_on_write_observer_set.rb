module Concurrent

  class CopyOnWriteObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    def add_observer(observer, func=:update)
      new_observers = observers.dup
      new_observers[observer] = func
      self.observers = new_observers
      func
    end

    def delete_observer(observer)
      new_observers = observers.dup
      new_observers.delete(observer)
      self.observers = new_observers
      observer
    end

    def delete_observers
      self.observers = {}
      self
    end

    def count_observers
      observers.count
    end

    def notify_observers(*args)
      notify_to(observers, *args)
      self
    end

    def notify_and_delete_observers(*args)
      old = clear_observers_and_return_old
      notify_to(old, *args)
      self
    end

    private

      def notify_to(observers, *args)
        observers.each do |observer, function|
          observer.send function, *args
        end
      end

      def observers
        @mutex.synchronize { @observers }
      end

      def observers=(new_set)
        @mutex.synchronize { @observers = new_set}
      end

      def clear_observers_and_return_old
        @mutex.synchronize do
          old_observers = @observers
          @observers = {}
          old_observers
        end

      end

  end
end
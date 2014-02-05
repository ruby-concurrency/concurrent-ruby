module Concurrent

  class CopyOnNotifyObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    def add_observer(observer, func=:update)
      @mutex.synchronize { @observers[observer] = func }
    end

    def delete_observer(observer)
      @mutex.synchronize { @observers.delete(observer) }
      observer
    end

    def delete_observers
      @mutex.synchronize { @observers.clear }
      self
    end

    def count_observers
      @mutex.synchronize { @observers.count }
    end

    def notify_observers(*args)
      observers = @mutex.synchronize { @observers.dup }
      notify_to(observers, *args)

      self
    end

    def notify_and_delete_observers(*args)
      observers = duplicate_and_clear_observers
      notify_to(observers, *args)

      self
    end

    private

      def duplicate_and_clear_observers
        @mutex.synchronize do
          observers = @observers.dup
          @observers.clear
          observers
        end
      end

      def notify_to(observers, *args)
        observers.each do |observer, function|
          observer.send function, *args
        end
      end

  end
end
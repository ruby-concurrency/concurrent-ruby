module Concurrent

  # A thread safe observer set implemented using copy-on-read approach:
  # observers are added and removed from a thread safe collection; every time
  # a notification is required the internal data structure is copied to
  # prevent concurrency issues
  class CopyOnNotifyObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    # Adds an observer to this set
    # @param [Object] observer the observer to add
    # @param [Symbol] func the function to call on the observer during notification. Default is :update
    # @return [Symbol] the added function
    def add_observer(observer, func=:update)
      @mutex.synchronize { @observers[observer] = func }
    end

    # @param [Object] observer the observer to remove
    # @return [Object] the deleted observer
    def delete_observer(observer)
      @mutex.synchronize { @observers.delete(observer) }
      observer
    end

    # Deletes all observers
    # @return [CopyOnWriteObserverSet] self
    def delete_observers
      @mutex.synchronize { @observers.clear }
      self
    end

    # @return [Integer] the observers count
    def count_observers
      @mutex.synchronize { @observers.count }
    end

    # Notifies all registered observers with optional args
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
    def notify_observers(*args)
      observers = @mutex.synchronize { @observers.dup }
      notify_to(observers, *args)

      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
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
module Concurrent

  # A thread safe observer set implemented using copy-on-write approach:
  # every time an observer is added or removed the whole internal data structure is
  # duplicated and replaced with a new one.
  class CopyOnWriteObserverSet

    def initialize
      @mutex = Mutex.new
      @observers = {}
    end

    # Adds an observer to this set
    # @param [Object] observer the observer to add
    # @param [Symbol] func the function to call on the observer during notification. Default is :update
    # @return [Symbol] the added function
    def add_observer(observer, func=:update)
      @mutex.synchronize do
        new_observers = @observers.dup
        new_observers[observer] = func
        @observers = new_observers
      end
      func
    end

    # @param [Object] observer the observer to remove
    # @return [Object] the deleted observer
    def delete_observer(observer)
      @mutex.synchronize do
        new_observers = @observers.dup
        new_observers.delete(observer)
        @observers = new_observers
      end
      observer
    end

    # Deletes all observers
    # @return [CopyOnWriteObserverSet] self
    def delete_observers
      self.observers = {}
      self
    end


    # @return [Integer] the observers count
    def count_observers
      observers.count
    end

    # Notifies all registered observers with optional args
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
    def notify_observers(*args)
      notify_to(observers, *args)
      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
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
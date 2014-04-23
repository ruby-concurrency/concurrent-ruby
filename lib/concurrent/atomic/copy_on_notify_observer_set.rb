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
      @mutex.lock
      @observers[observer] = func
      @mutex.unlock

      func
    end

    # @param [Object] observer the observer to remove
    # @return [Object] the deleted observer
    def delete_observer(observer)
      @mutex.lock
      @observers.delete(observer)
      @mutex.unlock

      observer
    end

    # Deletes all observers
    # @return [CopyOnWriteObserverSet] self
    def delete_observers
      @mutex.lock
      @observers.clear
      @mutex.unlock

      self
    end

    # @return [Integer] the observers count
    def count_observers
      @mutex.lock
      result = @observers.count
      @mutex.unlock

      result
    end

    # Notifies all registered observers with optional args
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
    def notify_observers(*args, &block)
      observers = duplicate_observers
      notify_to(observers, *args, &block)

      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
    def notify_and_delete_observers(*args, &block)
      observers = duplicate_and_clear_observers
      notify_to(observers, *args, &block)

      self
    end

    private

    def duplicate_and_clear_observers
      @mutex.lock
      observers = @observers.dup
      @observers.clear
      @mutex.unlock

      observers
    end

    def duplicate_observers
      @mutex.lock
      observers = @observers.dup
      @mutex.unlock

      observers
    end

    def notify_to(observers, *args)
      raise ArgumentError.new('cannot give arguments and a block') if block_given? && !args.empty?
      observers.each do |observer, function|
        args = yield if block_given?
        observer.send(function, *args)
      end
    end
  end
end

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
      @mutex.lock
      new_observers = @observers.dup
      new_observers[observer] = func
      @observers = new_observers
      @mutex.unlock

      func
    end

    # @param [Object] observer the observer to remove
    # @return [Object] the deleted observer
    def delete_observer(observer)
      @mutex.lock
      new_observers = @observers.dup
      new_observers.delete(observer)
      @observers = new_observers
      @mutex.unlock

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
    def notify_observers(*args, &block)
      notify_to(observers, *args, &block)
      self
    end

    # Notifies all registered observers with optional args and deletes them.
    #
    # @param [Object] args arguments to be passed to each observer
    # @return [CopyOnWriteObserverSet] self
    def notify_and_delete_observers(*args, &block)
      old = clear_observers_and_return_old
      notify_to(old, *args, &block)
      self
    end

    private

    def notify_to(observers, *args)
      raise ArgumentError.new('cannot give arguments and a block') if block_given? && !args.empty?
      observers.each do |observer, function|
        args = yield if block_given?
        observer.send(function, *args)
      end
    end

    def observers
      @mutex.lock
      o = @observers
      @mutex.unlock

      o
    end

    def observers=(new_set)
      @mutex.lock
      @observers = new_set
      @mutex.unlock
    end

    def clear_observers_and_return_old
      @mutex.lock
      old_observers = @observers
      @observers = {}
      @mutex.unlock

      old_observers
    end
  end
end

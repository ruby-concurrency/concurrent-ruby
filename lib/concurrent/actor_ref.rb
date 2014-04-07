require 'concurrent/copy_on_notify_observer_set'
require 'concurrent/utilities'

module Concurrent

  module ActorRef

    def running?
      true
    end

    def shutdown?
      false
    end

    def post(*msg, &block)
      raise NotImplementedError
    end

    def post!(*msg)
      raise NotImplementedError
    end

    def <<(message)
      post(*message)
      self
    end

    def add_observer(*args)
      @observers.add_observer(*args)
    end

    def delete_observer(*args)
      @observers.delete_observer(*args)
    end

    def delete_observers
      @observers.delete_observers
    end

    protected

    def observers
      @observers ||= CopyOnNotifyObserverSet.new
    end
  end
end

require 'concurrent/copy_on_notify_observer_set'

module Concurrent

  module ActorRef

    #NOTE: Required API methods
    #      Must be implemented in all subclasses
    #def post(*msg, &block)
    #def post!(*msg)
    #def running?
    #def shutdown?
    #def shutdown
    #def join(timeout = nil)

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

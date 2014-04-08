require 'concurrent/copy_on_notify_observer_set'
require 'concurrent/copy_on_write_observer_set'

module Concurrent

  module Observable

    def add_observer(*args)
      observers.add_observer(*args)
    end

    def delete_observer(*args)
      observers.delete_observer(*args)
    end

    def delete_observers
      observers.delete_observers
    end

    def count_observers
      observers.count_observers
    end

    protected

    attr_accessor :observers

    def observers
      @observers ||= CopyOnNotifyObserverSet.new
    end
  end
end

require 'concurrent/atomic/copy_on_notify_observer_set'
require 'concurrent/atomic/copy_on_write_observer_set'

module Concurrent

  module Observable

    # @return [Object] the added observer
    def add_observer(*args, &block)
      observers.add_observer(*args, &block)
    end

    # @return [Object] the deleted observer
    def delete_observer(*args)
      observers.delete_observer(*args)
    end

    # @return [Observable] self
    def delete_observers
      observers.delete_observers
      self
    end

    # @return [Integer] the observers count
    def count_observers
      observers.count_observers
    end

    protected

    attr_accessor :observers
  end
end

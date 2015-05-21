require 'concurrent/synchronization_object'

module Concurrent
  class WaitableList < SynchronizationObject

    def size
      synchronize { @list.size }
    end

    def empty?
      synchronize { @list.empty? }
    end

    def put(value)
      synchronize do
        @list << value
        ns_signal
      end
    end

    def delete(value)
      synchronize { @list.delete(value) }
    end

    def take
      synchronize do
        ns_wait_until { !@list.empty? }
        @list.shift
      end
    end

    protected

    def ns_initialize
      @list = []
    end
  end
end

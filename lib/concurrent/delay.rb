require 'concurrent/atomic/count_down_latch'
require 'concurrent/synchronization/object'

module Concurrent

  class Delay < Synchronization::Object

    STATES = [:pending, :computing, :resolved, :rejected].freeze

    def initialize(&block)
      raise ArgumentError.new('no block given') unless block_given?
      super(&nil)
      synchronize do
        @task   = block
        @reason = nil
        @state  = :pending
      end
    end

    def value
      synchronize do
        break unless @state == :pending
        @state = :computing
        begin
          set_state(true, @task.call, nil)
        rescue => ex
          set_state(false, nil, ex)
        end
      end
      @value
    end

    def reason
      synchronize { @reason }
    end

    def pending?
      synchronize { @state == :pending || @state == :computing }
    end

    def resolved?
      synchronize { @state == :resolved }
    end

    def rejected?
      synchronize { @state == :rejected }
    end

    def reconfigure(&block)
      synchronize do
        raise ArgumentError.new('no block given') unless block_given?
        if @state == :pending || @state == :rejected
          @state  = :pending
          @task   = block
          @reason = nil
          true
        else
          false
        end
      end
    end

    def realize_via(timeout, executor)
      latch = synchronize do
        if @state == :pending
          cdl = Concurrent::CountDownLatch.new(1)
          executor.post(self, cdl) {|d, l| d.value; l.count_down }
          cld
        else
          nil
        end
      end
      latch ? latch.wait(timeout) : true
    end

    private

    def set_state(success, value, reason)
      if success
        @value  = value
        @reason = nil
        @state  = :resolved
      else
        @value  = nil
        @reason = reason
        @state  = :rejected
      end
    end
  end
end

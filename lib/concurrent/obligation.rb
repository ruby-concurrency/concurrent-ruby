require 'thread'
require 'timeout'

require 'concurrent/dereferenceable'
require 'concurrent/event'

module Concurrent

  module Obligation
    include Dereferenceable

    # Has the obligation been fulfilled?
    # @return [Boolean]
    def fulfilled?() state == :fulfilled; end
    alias_method :realized?, :fulfilled?

    # Has the obligation been rejected?
    # @return [Boolean]
    def rejected?() state == :rejected; end

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?() state == :pending; end

    # Is the obligation still unscheduled?
    # @return [Boolean]
    def unscheduled?() state == :unscheduled; end

    def completed?
      [:fulfilled, :rejected].include? state
    end

    def incomplete?
      [:unscheduled, :pending].include? state
    end

    def value(timeout = nil)
      event.wait(timeout) if timeout != 0 && incomplete?
      super()
    end

    def state
      mutex.synchronize { @state }
    end

    def state=(value)
      mutex.synchronize { @state = value }
    end

    def reason
      mutex.synchronize { @reason }
    end

    protected

    def init_obligation
      init_mutex
      @event = Event.new
    end

    def event
      @event
    end

    def set_state(success, value, reason)
      if success
        @value = value
        @state = :fulfilled
      else
        @reason = reason
        @state = :rejected
      end
    end

    def value=(value)
      @value = value
    end

    def reason=(reason)
      @reason = reason
    end

    # atomic compare and set operation
    # state is set to next_state only if current state is == expected_current
    # @param [Symbol] next_state
    # @param [Symbol] expected_current
    # @return [Boolean] true is state is changed, false otherwise
    def compare_and_set_state(next_state, expected_current)
      mutex.synchronize do
        if @state == expected_current
          @state = next_state
          true
        else
          false
        end
      end
    end

    # executes the block within mutex if current state is included in expected_states
    # @return block value if executed, false otherwise
    def if_state(*expected_states)
      raise ArgumentError.new('no block given') unless block_given?

      mutex.synchronize do
        if expected_states.include? @state
          yield
        else
          false
        end
      end
    end

  end
end

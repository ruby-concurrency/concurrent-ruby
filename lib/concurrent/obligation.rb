require 'thread'
require 'timeout'

require 'concurrent/dereferenceable'
require 'concurrent/atomic/event'

module Concurrent

  module Obligation
    include Dereferenceable

    # Has the obligation been fulfilled?
    # @return [Boolean]
    def fulfilled?
      state == :fulfilled
    end
    alias_method :realized?, :fulfilled?

    # Has the obligation been rejected?
    # @return [Boolean]
    def rejected?
      state == :rejected
    end

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?
      state == :pending
    end

    # Is the obligation still unscheduled?
    # @return [Boolean]
    def unscheduled?
      state == :unscheduled
    end

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
      mutex.lock
      result = @state
      mutex.unlock
      result
    end

    def reason
      mutex.lock
      result = @reason
      mutex.unlock
      result
    end

    protected

    # @!visibility private
    def init_obligation # :nodoc:
      init_mutex
      @event = Event.new
    end

    # @!visibility private
    def event # :nodoc:
      @event
    end

    # @!visibility private
    def set_state(success, value, reason) # :nodoc:
      if success
        @value = value
        @state = :fulfilled
      else
        @reason = reason
        @state = :rejected
      end
    end

    # @!visibility private
    def state=(value) # :nodoc:
      mutex.synchronize { @state = value }
    end

    # atomic compare and set operation
    # state is set to next_state only if current state is == expected_current
    #
    # @param [Symbol] next_state
    # @param [Symbol] expected_current
    # 
    # @return [Boolean] true is state is changed, false otherwise
    #
    # @!visibility private
    def compare_and_set_state(next_state, expected_current) # :nodoc:
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
    #
    # @return block value if executed, false otherwise
    #
    # @!visibility private
    def if_state(*expected_states) # :nodoc:
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

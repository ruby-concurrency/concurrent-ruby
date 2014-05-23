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

    # @return [Object] see Dereferenceable#deref
    def value(timeout = nil)
      wait timeout
      deref
    end

    # wait until Obligation is #complete?
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Obligation] self
    def wait(timeout = nil)
      event.wait(timeout) if timeout != 0 && incomplete?
      self
    end

    # wait until Obligation is #complete?
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Obligation] self
    # @raise [Exception] when #rejected? it raises #reason
    def no_error!(timeout = nil)
      wait(timeout).tap { raise self if rejected? }
    end

    # @raise [Exception] when #rejected? it raises #reason
    # @return [Object] see Dereferenceable#deref
    def value!(timeout = nil)
      wait(timeout)
      if rejected?
        raise self
      else
        deref
      end
    end

    def state
      mutex.lock
      @state
    ensure
      mutex.unlock
    end

    def reason
      mutex.lock
      @reason
    ensure
      mutex.unlock
    end

    # @example allows Obligation to be risen
    #   rejected_ivar = Ivar.new.fail
    #   raise rejected_ivar
    def exception(*args)
      raise 'obligation is not rejected' unless rejected?
      reason.exception(*args)
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
        @state  = :rejected
      end
    end

    # @!visibility private
    def state=(value) # :nodoc:
      mutex.lock
      @state = value
    ensure
      mutex.unlock
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
      mutex.lock
      if @state == expected_current
        @state = next_state
        true
      else
        false
      end
    ensure
      mutex.unlock
    end

    # executes the block within mutex if current state is included in expected_states
    #
    # @return block value if executed, false otherwise
    #
    # @!visibility private
    def if_state(*expected_states) # :nodoc:
      mutex.lock
      raise ArgumentError.new('no block given') unless block_given?

      if expected_states.include? @state
        yield
      else
        false
      end
    ensure
      mutex.unlock
    end
  end
end

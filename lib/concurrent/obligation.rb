require 'thread'
require 'timeout'

require 'concurrent/dereferenceable'
require 'concurrent/event'

module Concurrent

  module Obligation
    include Dereferenceable

    attr_reader :state
    attr_reader :reason

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

    def value(timeout = nil)
      event.wait(timeout) unless timeout == 0 || state != :pending
      super()
    end

    def state
      mutex.synchronize { @state }
    end

    def state=(value)
      mutex.synchronize { @state = value }
    end

    protected

    def init_obligation
      init_mutex
      @event = Event.new
    end

    def event
      @event
    end

    def set_state(success, val, reason)
      if success
        @value = val
        @state = :fulfilled
      else
        @reason = reason
        @state = :rejected
      end
    end

  end
end

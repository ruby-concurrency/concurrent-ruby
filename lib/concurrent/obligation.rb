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

    def event
      @event ||= Event.new
    end

  end
end

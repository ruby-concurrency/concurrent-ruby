require 'thread'
require 'timeout'
require 'functional'

require 'concurrent/event'

behavior_info(:future,
              state: 0,
              value: -1,
              reason: 0,
              pending?: 0,
              fulfilled?: 0,
              rejected?: 0)

behavior_info(:promise,
              state: 0,
              value: -1,
              reason: 0,
              pending?: 0,
              fulfilled?: 0,
              rejected?: 0,
              then: 0,
              rescue: -1)

module Concurrent

  module Obligation

    attr_reader :state
    attr_reader :reason

    # Has the obligation been fulfilled?
    # @return [Boolean]
    def fulfilled?() return(@state == :fulfilled); end
    alias_method :realized?, :fulfilled?

    # Has the promise been rejected?
    # @return [Boolean]
    def rejected?() return(@state == :rejected); end

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?() return(@state == :pending); end

    def value(timeout = nil)
      event.wait(timeout) unless timeout == 0 || @state != :pending
      return @value
    end
    alias_method :deref, :value

    protected

    def event
      @event ||= Event.new
    end
  end
end

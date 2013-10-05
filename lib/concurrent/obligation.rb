require 'thread'
require 'timeout'
require 'functional'

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
      if timeout == 0 || ! pending?
        return @value
      elsif timeout.nil?
        return mutex.synchronize { v = @value }
      else
        begin
          return Timeout::timeout(timeout.to_f) {
            mutex.synchronize { v = @value }
          }
        rescue Timeout::Error => ex
          return nil
        end
      end
    end
    alias_method :deref, :value

    protected

    def mutex
      @mutex ||= Mutex.new
    end
  end
end

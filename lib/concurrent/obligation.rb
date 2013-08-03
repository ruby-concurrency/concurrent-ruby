require 'thread'
require 'timeout'

require 'functional/behavior'

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

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?() return(!(fulfilled? || rejected?)); end

    def value(timeout = nil)
      if !pending? || timeout == 0
        return @value
      elsif timeout.nil?
        return semaphore.synchronize { value = @value }
      else
        begin
          return Timeout::timeout(timeout.to_f) {
            semaphore.synchronize { value = @value }
          }
        rescue Timeout::Error => ex
          return nil
        end
      end
    end
    alias_method :deref, :value

    # Has the promise been rejected?
    # @return [Boolean]
    def rejected?() return(@state == :rejected); end

    protected

    def semaphore
      @semaphore ||= Mutex.new
    end
  end
end

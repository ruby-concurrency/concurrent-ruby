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
        return semaphore.synchronize { @value }
      else
        begin
          return Timeout::timeout(timeout.to_f) {
            semaphore.synchronize { @value }
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

module Kernel

  def deref(obligation, timeout = nil)
    if obligation.respond_to?(:deref)
      return obligation.deref(timeout)
    elsif obligation.respond_to?(:value)
      return obligation.deref(timeout)
    else
      return nil
    end
  end
  module_function :deref

  def pending?(obligation)
    if obligation.respond_to?(:pending?)
      return obligation.pending?
    else
      return false
    end
  end
  module_function :pending?

  def fulfilled?(obligation)
    if obligation.respond_to?(:fulfilled?)
      return obligation.fulfilled?
    elsif obligation.respond_to?(:realized?)
      return obligation.realized?
    else
      return false
    end
  end
  module_function :fulfilled?

  def realized?(obligation)
    if obligation.respond_to?(:realized?)
      return obligation.realized?
    elsif obligation.respond_to?(:fulfilled?)
      return obligation.fulfilled?
    else
      return false
    end
  end
  module_function :realized?

  def rejected?(obligation)
    if obligation.respond_to?(:rejected?)
      return obligation.rejected?
    else
      return false
    end
  end
  module_function :rejected?
end

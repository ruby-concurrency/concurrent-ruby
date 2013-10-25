require 'concurrent/obligation'

module Concurrent

  class Contract
    include Obligation

    def initialize
      @state = :pending
    end

    def complete(value, reason)
      @value = value
      @reason = reason
      @state = ( reason ? :rejected : :fulfilled )
      event.set
    end
  end
end

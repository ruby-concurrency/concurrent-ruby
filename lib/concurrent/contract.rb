require 'concurrent/obligation'

module Concurrent

  class Contract
    include Obligation

    def initialize(opts = {})
      @state = :pending
      init_mutex
      set_deref_options(opts)
    end

    def complete(value, reason)
      @value = value
      @reason = reason
      @state = ( reason ? :rejected : :fulfilled )
      event.set
    end
  end
end

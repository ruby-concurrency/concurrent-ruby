require 'concurrent/atomic'
require 'concurrent/delay'


module Concurrent
  # Allows to store lazy evaluated values under keys. Uses `Delay`s.
  # @example
  #     register = Concurrent::LazyRegister.new
  #     #=> #<Concurrent::LazyRegister:0x007fd7ecd5e230 @data=#<Concurrent::Atomic:0x007fd7ecd5e1e0>>
  #     register[:key]
  #     #=> nil
  #     register.add(:key) { Concurrent::Actor.spawn!(Actor::AdHoc, :ping) { -> message { message } } }
  #     #=> #<Concurrent::LazyRegister:0x007fd7ecd5e230 @data=#<Concurrent::Atomic:0x007fd7ecd5e1e0>>
  #     register[:key]
  #     #=> #<Concurrent::Actor::Reference /ping (Concurrent::Actor::AdHoc)>
  class LazyRegister
    def initialize
      @data = Atomic.new Hash.new
    end

    # @param [Object] key
    # @return value stored under the key
    # @raise Exception when the initialization block fails
    def [](key)
      delay = @data.get[key]
      delay.value! if delay
    end

    # @param [Object] key
    # @return [true, false] if the key is registered
    def registered?(key)
      @data.get.key? key
    end

    alias_method :key?, :registered?

    # @param [Object] key
    # @yield the object to store under the key
    # @return self
    def register(key, &block)
      delay = Delay.new(&block)
      @data.update { |h| h.merge key => delay }
      self
    end

    alias_method :add, :register

    # Un-registers the object under key, realized or not
    # @return self
    # @param [Object] key
    def unregister(key)
      @data.update { |h| h.dup.tap { |j| j.delete(key) } }
      self
    end

    alias_method :remove, :unregister
  end
end

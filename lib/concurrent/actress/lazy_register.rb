require 'concurrent/atomic'
require 'concurrent/delay'


module Concurrent
  module Actress

    # Implements lazy register for actors (or other objects)
    # @example
    #     register = Actress::LazyRegister.new
    #     #=> #<Concurrent::Actress::LazyRegister:0x007fd7ecd5e230 @data=#<Concurrent::Atomic:0x007fd7ecd5e1e0>>
    #     register[:key]
    #     #=> nil
    #     register.add(:key) { Actress.spawn(Actress::AdHoc, :ping) { -> message { message } } }
    #     #=> #<Concurrent::Actress::LazyRegister:0x007fd7ecd5e230 @data=#<Concurrent::Atomic:0x007fd7ecd5e1e0>>
    #     register[:key]
    #     #=> #<Concurrent::Actress::Reference /ping (Concurrent::Actress::AdHoc)>
    class LazyRegister
      def initialize
        @data = Atomic.new Hash.new
      end

      def [](key)
        delay = @data.get[key]
        delay.value! if delay
      end

      def registered?(key)
        @data.get.key? key
      end

      alias_method :key?, :registered?

      def register(key, &block)
        delay = Delay.new(&block)
        @data.update { |h| h.merge key => delay }
        self
      end

      alias_method :add, :register

      def unregister(key)
        @data.update { |h| h.dup.tap { |h| h.delete(key) } }
        self
      end

      alias_method :remove, :unregister
    end
  end
end

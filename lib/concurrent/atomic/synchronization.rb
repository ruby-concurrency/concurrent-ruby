module Concurrent

  # Safe synchronization under JRuby, prevents reading uninitialized @mutex variable.
  # @note synchronized needs to be called in #initialize for this module to work properly
  # @example usage
  #     class AClass
  #       include Synchronized
  #
  #       def initialize
  #         synchronize do
  #           # body of the constructor ...
  #         end
  #       end
  #
  #       def a_method
  #         synchronize do
  #           # body of a_method ...
  #         end
  #       end
  #     end
  module Synchronization

    engine = defined?(RUBY_ENGINE) && RUBY_ENGINE

    case engine
    when 'jruby'
      require 'jruby'

      def synchronize
        JRuby.reference0(self).synchronized { yield }
      end

    when 'rbx'

      def synchronize
        Rubinius.lock(self)
        yield
      ensure
        Rubinius.unlock(self)
      end

    else

      def synchronize
        @mutex ||= Mutex.new
        @mutex.synchronize { yield }
      end

    end
  end
end

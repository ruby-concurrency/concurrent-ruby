module Concurrent
  module Synchronization
    # Safe synchronization under any Ruby implementation.
    # It provides methods like {#synchronize}, {#ns_wait}, {#ns_signal} and {#ns_broadcast}.
    # Provides a single layer which can improve its implementation over time without changes needed to
    # the classes using it. Use {Synchronization::Object} not this abstract class.
    #
    # @note this object does not support usage together with
    #   [`Thread#wakeup`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-wakeup)
    #   and [`Thread#raise`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-raise).
    #   `Thread#sleep` and `Thread#wakeup` will work as expected but mixing `Synchronization::Object#wait` and
    #   `Thread#wakeup` will not work on all platforms.
    #
    # @see {Event} implementation as an example of this class use
    #
    # @example simple
    #   class AnClass < Synchronization::Object
    #     def initialize
    #       super
    #       synchronize { @value = 'asd' }
    #     end
    #
    #     def value
    #       synchronize { @value }
    #     end
    #   end
    class AbstractObject

      # @abstract for helper ivar initialization if needed,
      #   otherwise it can be left empty. It has to call ns_initialize.
      def initialize(*args, &block)
        raise NotImplementedError
      end

      protected

      # @yield runs the block synchronized against this object,
      #   equivalent of java's `synchronize(this) {}`
      # @note can by made public in descendants if required by `public :synchronize`
      def synchronize
        raise NotImplementedError
      end

      # initialization of the object called inside synchronize block
      def ns_initialize(*args, &block)
      end

      # Wait until condition is met or timeout passes,
      # protects against spurious wake-ups.
      # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
      # @yield condition to be met
      # @yieldreturn [true, false]
      # @return [true, false] if condition met
      # @note only to be used inside synchronized block
      # @note to provide direct access to this method in a descendant add method
      #   ```
      #   def wait_until(timeout = nil, &condition)
      #     synchronize { ns_wait_until(timeout, &condition) }
      #   end
      #   ```
      def ns_wait_until(timeout = nil, &condition)
        if timeout
          wait_until = Concurrent.monotonic_time + timeout
          loop do
            now              = Concurrent.monotonic_time
            condition_result = condition.call
            # 0.001 correction to avoid error when `wait_until - now` is smaller than 0.0005 and rounded to 0
            # when passed to java #wait(long timeout)
            return condition_result if (now + 0.001) >= wait_until || condition_result
            ns_wait wait_until - now
          end
        else
          ns_wait timeout until condition.call
          true
        end
      end

      # Wait until another thread calls #signal or #broadcast,
      # spurious wake-ups can happen.
      #
      # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
      # @return [self]
      # @note only to be used inside synchronized block
      # @note to provide direct access to this method in a descendant add method
      #   ```
      #   def wait(timeout = nil)
      #     synchronize { ns_wait(timeout) }
      #   end
      #   ```
      def ns_wait(timeout = nil)
        raise NotImplementedError
      end

      # Signal one waiting thread.
      # @return [self]
      # @note only to be used inside synchronized block
      # @note to provide direct access to this method in a descendant add method
      #   ```
      #   def signal
      #     synchronize { ns_signal }
      #   end
      #   ```
      def ns_signal
        raise NotImplementedError
      end

      # Broadcast to all waiting threads.
      # @return [self]
      # @note only to be used inside synchronized block
      # @note to provide direct access to this method in a descendant add method
      #   ```
      #   def broadcast
      #     synchronize { ns_broadcast }
      #   end
      #   ```
      def ns_broadcast
        raise NotImplementedError
      end

      # Allows to construct immutable objects where all fields are visible after initialization, not requiring
      # further synchronization on access.
      # @example
      #   class AClass
      #     attr_reader :val
      #     def initialize(val)
      #       @val = val # final value, after assignment it's not changed (just convention, not enforced)
      #       ensure_ivar_visibility!
      #       # now it can be shared as Java's final field
      #     end
      #   end
      def ensure_ivar_visibility!
        raise NotImplementedError
      end

      # creates methods for reading and writing to a instance variable with volatile (Java semantic) instance variable
      # return [Array<Symbol>] names of defined method names
      def self.attr_volatile(*names)
        names.each do |name|
          ivar = :"@volatile_#{name}"
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              #{ivar}
            end

            def #{name}=(value)
              #{ivar} = value
            end
          RUBY
        end
        names.map { |n| [n, :"#{n}="] }.flatten
      end
    end
  end
end

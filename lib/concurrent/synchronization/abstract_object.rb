module Concurrent
  # TODO rename to Synchronization
  # TODO add newCondition
  module Synchronization
    # Safe synchronization under any Ruby implementation.
    # It provides methods like {#synchronize}, {#wait}, {#signal} and {#broadcast}.
    # Provides a single layer which can improve its implementation over time without changes needed to
    # the classes using it. Use {Synchronization::Object} not this abstract class.
    #
    # @note this object does not support usage together with {Thread#wakeup} and {Thread#raise}.
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
      #     otherwise it can be left empty.
      def initialize
        raise NotImplementedError
      end

      # @yield runs the block synchronized against this object,
      #   equvivalent of java's `synchronize(this) {}`
      def synchronize
        raise NotImplementedError
      end

      private

      # wait until another thread calls #signal or #broadcast,
      # spurious wake-ups can happen.
      # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
      # @return [self]
      # @note intended to be made public if required in child classes
      def wait(timeout = nil)
        synchronize { ns_wait(timeout) }
        self
      end

      # Wait until condition is met or timeout passes,
      # protects against spurious wake-ups.
      # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
      # @yield condition to be met
      # @yieldreturn [true, false]
      # @return [true, false]
      # @note intended to be made public if required in child classes
      def wait_until(timeout = nil, &condition)
        synchronize { ns_wait_until(timeout, &condition) }
      end

      # signal one waiting thread
      # @return [self]
      # @note intended to be made public if required in child classes
      def signal
        synchronize { ns_signal }
        self
      end

      # broadcast to all waiting threads
      # @return [self]
      # @note intended to be made public if required in child classes
      def broadcast
        synchronize { ns_broadcast }
        self
      end

      # @note only to be used inside synchronized block
      # @yield condition
      # @return [true, false]
      # see #wait_until
      def ns_wait_until(timeout, &condition)
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

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #wait
      def ns_wait(timeout = nil)
        raise NotImplementedError
      end

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #signal
      def ns_signal
        raise NotImplementedError
      end

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #broadcast
      def ns_broadcast
        raise NotImplementedError
      end

      # @example
      # def initialize
      #   @val = :val # final never changed value
      #   ensure_ivar_visibility!
      #   # not it can be shared as Java's immutable objects with final fields
      # end
      def ensure_ivar_visibility!
        raise NotImplementedError
      end

      def self.attr_volatile *names
        attr_accessor *names.map { |name| :"volatile_#{name}" }
      end

      module CasAttributes
        def list_attr_volatile_cas
          @attr_volatile_cas_names ||= []
          # @attr_volatile_cas_names +
          #     if superclass.respond_to?(:list_attr_volatile_cas)
          #       superclass.list_attr_volatile_cas
          #     else
          #       []
          #     end
        end

        def attr_volatile_cas *names
          names.each do |name|
            class_eval <<-RUBY
            def #(name}
              #{CasAttributes.ivar_name(name)}.get
            end

            def #(name}=(value)
              #{CasAttributes.ivar_name(name)}.set value
            end

            def #(name}_cas(old, value)
              #{CasAttributes.ivar_name(name)}.compare_and_set old, value
            end

            RUBY

            define_method name do
              instance_variable_get CasAttributes.ivar_name(name)
            end

            define_method "#{name}=" do |value|
              instance_variable_set CasAttributes.ivar_name(name), value
              Rubinius.memory_barrier
            end
          end
        end

        def self.ivar_name(name)
          :"@volatile_cas_#{name}"
        end

        def self.extended(base)
          base.include InstanceMethods
        end

        module InstanceMethods
          def initialize
            self.class.list_attr_volatile_cas.each do |name|
              isntance_variable_set CasAttributes.ivar_name(name), Atomic.new(nil)
            end
            ensure_ivar_visibility!
            super
          end
        end
      end
    end
  end
end

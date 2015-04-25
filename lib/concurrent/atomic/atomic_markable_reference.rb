module Edge
  module Concurrent
    # @!macro atomic_markable_reference
    class AtomicMarkableReference < ::Concurrent::Synchronization::Object
      # TODO: Remove once out of edge module
      include ::Concurrent

      # @!macro [attach] atomic_markable_reference_method_initialize
      def initialize(value = nil, mark = false)
        super
        @reference = AtomicReference.new ImmutableArray[value, mark]
        ensure_ivar_visibility!
      end

      # @!macro [attach] atomic_markable_reference_method_compare_and_set
      #
      #   Atomically sets the value and mark to the given updated value and
      #   mark given both:
      #     - the current value == the expected value &&
      #     - the current mark == the expected mark
      #
      #   @param [Object] old_val the expected value
      #   @param [Object] new_val the new value
      #   @param [Boolean] old_mark the expected mark
      #   @param [Boolean] new_mark the new mark
      #
      #   @return [Boolean] `true` if successful. A `false` return indicates
      #   that the actual value was not equal to the expected value or the
      #   actual mark was not equal to the expected mark
      def compare_and_set(expected_val, new_val, expected_mark, new_mark)
        # Memoize a valid reference to the current AtomicReference for
        # later comparison.
        current = @reference.get
        curr_val, curr_mark = current

        # Ensure that that the expected values match.
        return false unless (expected_val == curr_val) &&
                            (expected_mark == curr_mark)

        # In this case, it would be redundant to set the fields. Just
        # shortcircuit without wasting CPU time on CAS.
        return true if (new_val == curr_val) &&
                       (new_mark == curr_mark)

        prospect = ImmutableArray[new_val, new_mark]

        @reference.compare_and_set current, prospect
      end

      # @!macro [attach] atomic_markable_reference_method_get
      #
      #   Gets the current reference and marked values.
      #
      #   @return [ImmutableArray] the current reference and marked values
      def get
        @reference.get
      end

      # @!macro [attach] atomic_markable_reference_method_value
      #
      #   Gets the current value of the reference
      #
      #   @return [Object] the current value of the reference
      def value
        @reference.get[0]
      end

      # @!macro [attach] atomic_markable_reference_method_mark
      #
      #   Gets the current marked value
      #
      #   @return [Boolean] the current marked value
      def mark
        @reference.get[1]
      end
      alias_method :marked?, :mark

      # @!macro [attach] atomic_markable_reference_method_set
      #
      #   _Unconditionally_ sets to the given value of both the reference and
      #   the mark.
      #
      #   @param [Object] new_val the new value
      #   @param [Boolean] new_mark the new mark
      #
      #   @return [ImmutableArray] both the new value and the new mark
      def set(new_val, new_mark)
        ImmutableArray[new_val, new_mark].tap do |pair|
          @reference.set pair
        end
      end

      # @!macro [attach] atomic_markable_reference_method_update
      #
      # Pass the current value and marked state to the given block, replacing it
      # with the block's results. May retry if the value changes during the
      # block's execution.
      #
      # @yield [Object] Calculate a new value and marked state for the atomic
      #   reference using given (old) value and (old) marked
      # @yieldparam [Object] old_val the starting value of the atomic reference
      # @yieldparam [Boolean] old_mark the starting state of marked
      #
      # @return [ImmutableArray] the new value and new mark
      def update
        loop do
          old_val, old_mark = value, marked?
          new_val, new_mark = yield old_val, old_mark

          if compare_and_set old_val, new_val, old_mark, new_mark
            return ImmutableArray[new_val, new_mark]
          end
        end
      end

      # @!macro [attach] atomic_markable_reference_method_try_update
      #
      # Pass the current value to the given block, replacing it
      # with the block's result. Raise an exception if the update
      # fails.
      #
      # @yield [Object] Calculate a new value and marked state for the atomic
      #   reference using given (old) value and (old) marked
      # @yieldparam [Object] old_val the starting value of the atomic reference
      # @yieldparam [Boolean] old_mark the starting state of marked
      #
      # @return [ImmutableArray] the new value and marked state
      #
      # @raise [Concurrent::ConcurrentUpdateError] if the update fails
      def try_update
        old_val, old_mark = value, marked?
        new_val, new_mark = yield old_val, old_mark

        unless compare_and_set old_val, new_val, old_mark, new_mark
          fail ::Concurrent::ConcurrentUpdateError,
               'AtomicMarkableReference: Update failed due to race condition.',
               'Note: If you would like to guarantee an update, please use ' \
               'the `AtomicMarkableReference#update` method.'
        end

        ImmutableArray[new_val, new_mark]
      end

      # Internal/private ImmutableArray for representing pairs
      class ImmutableArray < Array
        def self.new(*args)
          super(*args).freeze
        end
      end
    end
  end
end

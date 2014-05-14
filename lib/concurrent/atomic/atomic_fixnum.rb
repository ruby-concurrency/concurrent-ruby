module Concurrent

  # @!macro [attach] atomic_fixnum
  #
  #   A numeric value that can be updated atomically. Reads and writes to an atomic
  #   fixnum and thread-safe and guaranteed to succeed. Reads and writes may block
  #   briefly but no explicit locking is required.
  #
  #   @since 0.5.0
  #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicLong.html java.util.concurrent.atomic.AtomicLong
  class MutexAtomicFixnum

    # @!macro [attach] atomic_fixnum_method_initialize
    #
    # Creates a new `AtomicFixnum` with the given initial value.
    #
    # @param [Fixnum] init the initial value
    # @raise [ArgumentError] if the initial value is not a `Fixnum`
    def initialize(init = 0)
      raise ArgumentError.new('initial value must be a Fixnum') unless init.is_a?(Fixnum)
      @value = init
      @mutex = Mutex.new
    end

    # @!macro [attach] atomic_fixnum_method_value
    #
    #   Retrieves the current `Fixnum` value.
    #
    #   @return [Fixnum] the current value
    def value
      @mutex.lock
      result = @value
      @mutex.unlock

      result
    end

    # @!macro [attach] atomic_fixnum_method_value_eq
    #
    #   Explicitly sets the value.
    #
    #   @param [Fixnum] value the new value to be set
    #
    #   @return [Fixnum] the current value
    #
    #   @raise [ArgumentError] if the new value is not a `Fixnum`
    def value=(value)
      raise ArgumentError.new('value must be a Fixnum') unless value.is_a?(Fixnum)
      @mutex.lock
      result = @value = value
      @mutex.unlock

      result
    end

    # @!macro [attach] atomic_fixnum_method_increment
    #
    #   Increases the current value by 1.
    #
    #   @return [Fixnum] the current value after incrementation
    def increment
      @mutex.lock
      @value += 1
      result = @value
      @mutex.unlock

      result
    end

    alias_method :up, :increment

    # @!macro [attach] atomic_fixnum_method_decrement
    #
    #   Decreases the current value by 1.
    #
    #   @return [Fixnum] the current value after decrementation
    def decrement
      @mutex.lock
      @value -= 1
      result = @value
      @mutex.unlock

      result
    end

    alias_method :down, :decrement

    # @!macro [attach] atomic_fixnum_method_compare_and_set
    # 
    #   Atomically sets the value to the given updated value if the current
    #   value == the expected value.
    #
    #   @param [Fixnum] expect the expected value
    #   @param [Fixnum] update the new value
    #
    #   @return [Boolean] true if the value was updated else false 
    def compare_and_set(expect, update)
      @mutex.lock
      if @value == expect
        @value = update
        result = true
      else
        result = false
      end
      @mutex.unlock

      result
    end
  end

  if RUBY_PLATFORM == 'java'

    # @!macro atomic_fixnum
    class JavaAtomicFixnum

      # @!macro atomic_fixnum_method_initialize
      #
      def initialize(init = 0)
        raise ArgumentError.new('initial value must be a Fixnum') unless init.is_a?(Fixnum)
        @atomic = java.util.concurrent.atomic.AtomicLong.new(init)
      end

      # @!macro atomic_fixnum_method_value
      #
      def value
        @atomic.get
      end

      # @!macro atomic_fixnum_method_value_eq
      #
      def value=(value)
        raise ArgumentError.new('value must be a Fixnum') unless value.is_a?(Fixnum)
        @atomic.set(value)
      end

      # @!macro atomic_fixnum_method_increment
      #
      def increment
        @atomic.increment_and_get
      end

      alias_method :up, :increment

      # @!macro atomic_fixnum_method_decrement
      #
      def decrement
        @atomic.decrement_and_get
      end

      alias_method :down, :decrement

      # @!macro atomic_fixnum_method_compare_and_set
      #
      def compare_and_set(expect, update)
        @atomic.compare_and_set(expect, update)
      end
    end

    # @!macro atomic_fixnum
    class AtomicFixnum < JavaAtomicFixnum
    end

  else

    # @!macro atomic_fixnum
    class AtomicFixnum < MutexAtomicFixnum
    end
  end
end

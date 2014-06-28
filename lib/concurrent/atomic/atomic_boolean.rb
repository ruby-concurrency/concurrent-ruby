module Concurrent

  # @!macro [attach] atomic_boolean
  #
  #   A boolean value that can be updated atomically. Reads and writes to an atomic
  #   boolean and thread-safe and guaranteed to succeed. Reads and writes may block
  #   briefly but no explicit locking is required.
  #
  #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicBoolean.html java.util.concurrent.atomic.AtomicBoolean
  class MutexAtomicBoolean

    # @!macro [attach] atomic_boolean_method_initialize
    #
    #   Creates a new `AtomicBoolean` with the given initial value.
    #
    #   @param [Boolean] initial the initial value
    def initialize(initial = false)
      @value = !!initial
      @mutex = Mutex.new
    end

    # @!macro [attach] atomic_boolean_method_value_get
    #
    #   Retrieves the current `Boolean` value.
    #
    #   @return [Boolean] the current value
    def value
      @mutex.lock
      @value
    ensure
      @mutex.unlock
    end

    # @!macro [attach] atomic_boolean_method_value_set
    #
    #   Explicitly sets the value.
    #
    #   @param [Boolean] value the new value to be set
    #
    #   @return [Boolean] the current value
    def value=(value)
      @mutex.lock
      @value = !!value
      @value
    ensure
      @mutex.unlock
    end

    # @!macro [attach] atomic_boolean_method_true_question
    #
    #   Is the current value `true`
    #
    #   @return [Boolean] true if the current value is `true`, else false
    def true?
      @mutex.lock
      @value
    ensure
      @mutex.unlock
    end

    # @!macro atomic_boolean_method_false_question
    #
    #   Is the current value `false`
    #
    #   @return [Boolean] true if the current value is `false`, else false
    def false?
      @mutex.lock
      !@value
    ensure
      @mutex.unlock
    end

    # @!macro [attach] atomic_boolean_method_make_true
    #
    #   Explicitly sets the value to true.
    #
    #   @return [Boolean] true is value has changed, otherwise false
    def make_true
      @mutex.lock
      old = @value
      @value = true
      !old
    ensure
      @mutex.unlock
    end

    # @!macro [attach] atomic_boolean_method_make_false
    #
    #   Explicitly sets the value to false.
    #
    #   @return [Boolean] true is value has changed, otherwise false
    def make_false
      @mutex.lock
      old = @value
      @value = false
      old
    ensure
      @mutex.unlock
    end
  end

  if RUBY_PLATFORM == 'java'

    # @!macro atomic_boolean
    class JavaAtomicBoolean

      # @!macro atomic_boolean_method_initialize
      #
      def initialize(initial = false)
        @atomic = java.util.concurrent.atomic.AtomicBoolean.new(!!initial)
      end

      # @!macro atomic_boolean_method_value_get
      #
      def value
        @atomic.get
      end

      # @!macro atomic_boolean_method_value_set
      #
      def value=(value)
        @atomic.set(!!value)
      end

      # @!macro atomic_boolean_method_true_question
      def true?
        @atomic.get
      end

      # @!macro atomic_boolean_method_false_question
      def false?
        !@atomic.get
      end

      # @!macro atomic_boolean_method_make_true
      def make_true
        @atomic.compareAndSet(false, true)
      end

      # @!macro atomic_boolean_method_make_false
      def make_false
        @atomic.compareAndSet(true, false)
      end
    end

    # @!macro atomic_boolean
    class AtomicBoolean < JavaAtomicBoolean
    end

  elsif defined? Concurrent::CAtomicBoolean

    # @!macro atomic_boolean
    class CAtomicBoolean

      # @!method initialize
      #   @!macro atomic_boolean_method_initialize

      # @!method value
      #   @!macro atomic_boolean_method_value_get

      # @!method value=
      #   @!macro atomic_boolean_method_value_set

      # @!method true?
      #   @!macro atomic_boolean_method_true_question

      # @!method false?
      #   @!macro atomic_boolean_method_false_question

      # @!method make_true
      #   @!macro atomic_boolean_method_make_true

      # @!method make_false
      #   @!macro atomic_boolean_method_make_false
    end

    # @!macro atomic_boolean
    class AtomicBoolean < CAtomicBoolean
    end

  else

    # @!macro atomic_boolean
    class AtomicBoolean < MutexAtomicBoolean
    end
  end
end

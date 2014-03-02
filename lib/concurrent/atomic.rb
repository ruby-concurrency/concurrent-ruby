module Concurrent

  # @!visibility private
  module MutexAtomicFixnum # :nodoc:

    # @!visibility private
    def allocate_storage(init) # :nodoc:
      @value = init
      @mutex = Mutex.new
    end

    def value
      @mutex.synchronize do
        @value
      end
    end

    def value=(value)
      raise ArgumentError.new('value must be a Fixnum') unless value.is_a?(Fixnum)
      @mutex.synchronize do
        @value = value
      end
    end

    def increment
      @mutex.synchronize do
        @value += 1
      end
    end

    def decrement
      @mutex.synchronize do
        @value -= 1
      end
    end

    # @!visibility private
    def compare_and_set(expect, update) # :nodoc:
      @mutex.synchronize do
        if @value == expect
          @value = update
          true
        else
          false
        end
      end
    end
  end

  # @!visibility private
  module JavaAtomicFixnum # :nodoc:

    # @!visibility private
    def allocate_storage(init) # :nodoc:
      @atomic = java.utli.concurrent.atomic.AtomicLong.new(init)
    end

    def value
      @atomic.get
    end

    def value=(value)
      raise ArgumentError.new('value must be a Fixnum') unless value.is_a?(Fixnum)
      @atomic.set(value)
    end

    def increment
      @atomic.incrementAndGet
    end

    def decrement
      @atomic.decrementAndGet
    end

    # @!visibility private
    def compare_and_set(expect, update) # :nodoc:
      @atomic.compare_and_set(expect, update)
    end
  end

  # A numeric value that can be updated atomically. Reads and writes to an atomic
  # fixnum and thread-safe and guaranteed to succeed. Reads and writes may block
  # briefly but no explicit locking is required.
  #
  # @!method value()
  #   Retrieves the current +Fixnum+ value
  #   @return [Fixnum] the current value
  #
  # @!method value=(value)
  #   Explicitly sets the value
  #   @param [Fixnum] value the new value to be set
  #   @return [Fixnum] the current value
  #   @raise [ArgumentError] if the new value is not a +Fixnum+
  #
  # @!method increment()
  #   Increases the current value by 1
  #   @return [Fixnum] the current value after incrementation
  #
  # @!method decrement()
  #   Decreases the current value by 1
  #   @return [Fixnum] the current value after decrementation
  #
  # @since 0.5.0
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicLong.html java.util.concurrent.atomic.AtomicLong
  class AtomicFixnum

    # Creates a new +AtomicFixnum+ with the given initial value.
    #
    # @param [Fixnum] init the initial value
    # @raise [ArgumentError] if the initial value is not a +Fixnum+
    def initialize(init = 0)
      raise ArgumentError.new('initial value must be a Fixnum') unless init.is_a?(Fixnum)
      allocate_storage(init)
    end

    if defined? java.utli.concurrent.atomic.AtomicLong.new
      include JavaAtomicFixnum
    else
      include MutexAtomicFixnum
    end

    alias_method :up, :increment
    alias_method :down, :decrement
  end
end

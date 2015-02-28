module Concurrent

  # Lazy evaluation of a block yielding an immutable result. Useful for
  # expensive operations that may never be needed. `LazyReference` is a simpler,
  # blocking version of `Delay` and has an API similar to `AtomicReference`.
  # The first time `#value` is called the caller will block until the
  # block given at construction is executed. Once the result has been
  # computed the value will be immutably set. Any exceptions thrown during
  # computation will be suppressed.
  #
  # Because of its simplicity `LazyReference` is much faster than `Delay`:
  #
  #            user     system      total        real
  #     Benchmarking Delay...
  #        0.730000   0.000000   0.730000 (  0.738434)
  #     Benchmarking LazyReference...
  #        0.040000   0.000000   0.040000 (  0.042322)
  #
  # @see Concurrent::Delay
  class LazyReference

    # Creates anew unfulfilled object.
    #
    # @yield the delayed operation to perform
    # @param [Object] default (nil) the default value for the object when
    #   the block raises an exception
    #
    # @raise [ArgumentError] if no block is given
    def initialize(default = nil, &block)
      raise ArgumentError.new('no block given') unless block_given?
      @default = default
      @task = block
      @mutex = Mutex.new
      @value = nil
      @fulfilled = false
    end

    # The calculated value of the object or the default value if one
    # was given at construction. This first time this method is called
    # it will block indefinitely while the block is processed.
    # Subsequent calls will not block.
    #
    # @return [Object] the calculated value
    def value
      # double-checked locking is safe because we only update once
      return @value if @fulfilled

      @mutex.synchronize do
        unless @fulfilled
          begin
            @value = @task.call
          rescue
            @value = @default
          ensure
            @fulfilled = true
          end
        end
        return @value
      end
    end
  end
end

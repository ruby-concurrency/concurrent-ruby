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
  #     Rehearsal -------------------------------------------------------
  #     Delay#value           0.210000   0.000000   0.210000 (  0.208207)
  #     Delay#value!          0.240000   0.000000   0.240000 (  0.247136)
  #     LazyReference#value   0.160000   0.000000   0.160000 (  0.158399)
  #     ---------------------------------------------- total: 0.610000sec
  #     
  #                               user     system      total        real
  #     Delay#value           0.200000   0.000000   0.200000 (  0.203602)
  #     Delay#value!          0.250000   0.000000   0.250000 (  0.252535)
  #     LazyReference#value   0.150000   0.000000   0.150000 (  0.154053)
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

    def value
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
      end
      return @value
    end
  end
end

module Kernel

  # Perform the given block as though it were an atomic operation. This means
  # that the Ruby scheduler cannot premept the block and context switch to
  # another thread. Basically a light wrapper around Ruby's Fiber class.
  #
  # @note Be very careful about what operations you perform within an atomic
  # block. Blocking operations such as I/O should *never* occur within an
  # atomic block. In those cases the entire Ruby VM will lock until the
  # blocking operation is complete. This would be bad.
  #
  # @yield calls the block
  # @yieldparam args an arbitrary set of block arguments
  #
  # @param [Array] zero more more optional arguments to pass to the block
  def atomic(*args)
    raise ArgumentError.new('no block given') unless block_given?
    return Fiber.new {
      yield(*args)
    }.resume
  end
  module_function :atomic
end

class Mutex

  def sync_with_timeout(timeout)
    Timeout::timeout(timeout) {
      self.synchronize {
        yield
      }
    }
  end
end

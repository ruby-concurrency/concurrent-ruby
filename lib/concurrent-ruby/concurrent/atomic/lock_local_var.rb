require_relative 'fiber_local_var'
require_relative 'thread_local_var'

module Concurrent
  def self.mutex_owned_per_thread?
    mutex = Mutex.new

    # Lock the mutex:
    mutex.synchronize do
      # Check if the mutex is still owned in a child fiber:
      Fiber.new{mutex.owned?}.resume
    end
  end

  if mutex_owned_per_thread?
    LockLocalVar = ThreadLocalVar
  else
    LockLocalVar = FiberLocalVar
  end
end

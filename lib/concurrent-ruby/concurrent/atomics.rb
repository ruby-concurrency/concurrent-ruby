# frozen_string_literal: true

module Concurrent
  autoload :AtomicReference, 'concurrent/atomic/atomic_reference'
  autoload :AtomicBoolean, 'concurrent/atomic/atomic_boolean'
  autoload :AtomicFixnum, 'concurrent/atomic/atomic_fixnum'
  autoload :CyclicBarrier, 'concurrent/atomic/cyclic_barrier'
  autoload :MutexCountDownLatch, 'concurrent/atomic/count_down_latch'
  autoload :Event, 'concurrent/atomic/event'
  autoload :ReadWriteLock, 'concurrent/atomic/read_write_lock'
  autoload :ReentrantReadWriteLock, 'concurrent/atomic/reentrant_read_write_lock'
  autoload :MutexSemaphore, 'concurrent/atomic/semaphore'
  autoload :ThreadLocalVar, 'concurrent/atomic/thread_local_var'
end

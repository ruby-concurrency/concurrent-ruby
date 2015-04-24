require 'thread'
require 'concurrent/atomic/atomic_reference'
require 'concurrent/errors'

module Concurrent

  # Ruby read-write lock implementation
  #
  # Allows any number of concurrent readers, but only one concurrent writer
  # (And if the "write" lock is taken, any readers who come along will have to wait)
  #
  # If readers are already active when a writer comes along, the writer will wait for
  # all the readers to finish before going ahead.
  # Any additional readers that come when the writer is already waiting, will also
  # wait (so writers are not starved).
  #
  # This implementation is based on `java.util.concurrent.ReentrantReadWriteLock`.
  #
  # @example
  #   lock = Concurrent::ReadWriteLock.new
  #   lock.with_read_lock  { data.retrieve }
  #   lock.with_write_lock { data.modify! }
  #
  # @note Do **not** try to acquire the write lock while already holding a read lock
  #   **or** try to acquire the write lock while you already have it.
  #   This will lead to deadlock
  #
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/locks/ReentrantReadWriteLock.html java.util.concurrent.ReentrantReadWriteLock
  class ReadWriteLock

    # @!visibility private
    WAITING_WRITER  = 1 << 15

    # @!visibility private
    RUNNING_WRITER  = 1 << 30

    # @!visibility private
    MAX_READERS     = WAITING_WRITER - 1

    # @!visibility private
    MAX_WRITERS     = RUNNING_WRITER - MAX_READERS - 1

    # Implementation notes: 
    # A goal is to make the uncontended path for both readers/writers lock-free
    # Only if there is reader-writer or writer-writer contention, should locks be used
    # Internal state is represented by a single integer ("counter"), and updated 
    #  using atomic compare-and-swap operations
    # When the counter is 0, the lock is free
    # Each reader increments the counter by 1 when acquiring a read lock
    #   (and decrements by 1 when releasing the read lock)
    # The counter is increased by (1 << 15) for each writer waiting to acquire the
    #   write lock, and by (1 << 30) if the write lock is taken

    # Create a new `ReadWriteLock` in the unlocked state.
    def initialize
      @counter      = AtomicReference.new(0)  # single integer which represents lock state
      @reader_q     = ConditionVariable.new   # queue for waiting readers
      @reader_mutex = Mutex.new               # to protect reader queue
      @writer_q     = ConditionVariable.new   # queue for waiting writers
      @writer_mutex = Mutex.new               # to protect writer queue
    end

    # Execute a block operation within a read lock.
    #
    # @yield the task to be performed within the lock.
    #
    # @return [Object] the result of the block operation.
    #
    # @raise [ArgumentError] when no block is given.
    # @raise [Concurrent::ResourceLimitError] if the maximum number of readers
    #   is exceeded.
    def with_read_lock
      raise ArgumentError.new('no block given') unless block_given?
      acquire_read_lock
      begin
        yield
      ensure
        release_read_lock
      end
    end

    # Execute a block operation within a write lock.
    #
    # @yield the task to be performed within the lock.
    #
    # @return [Object] the result of the block operation.
    #
    # @raise [ArgumentError] when no block is given.
    # @raise [Concurrent::ResourceLimitError] if the maximum number of readers
    #   is exceeded.
    def with_write_lock
      raise ArgumentError.new('no block given') unless block_given?
      acquire_write_lock
      begin
        yield
      ensure
        release_write_lock
      end
    end

    # Acquire a read lock. If a write lock has been acquired will block until
    # it is released. Will not block if other read locks have been acquired.
    #
    # @return [Boolean] true if the lock is successfully acquired
    #
    # @raise [Concurrent::ResourceLimitError] if the maximum number of readers
    #   is exceeded.
    def acquire_read_lock
      while(true)
        c = @counter.value
        raise ResourceLimitError.new('Too many reader threads') if max_readers?(c)

        # If a writer is waiting when we first queue up, we need to wait
        if waiting_writer?(c)
          # But it is possible that the writer could finish and decrement @counter right here...
          @reader_mutex.synchronize do 
            # So check again inside the synchronized section
            @reader_q.wait(@reader_mutex) if waiting_writer?
          end

          # after a reader has waited once, they are allowed to "barge" ahead of waiting writers
          # but if a writer is *running*, the reader still needs to wait (naturally)
          while(true)
            c = @counter.value
            if running_writer?(c)
              @reader_mutex.synchronize do
                @reader_q.wait(@reader_mutex) if running_writer?
              end
            else
              return if @counter.compare_and_swap(c,c+1)
            end
          end
        else
          break if @counter.compare_and_swap(c,c+1)
        end
      end    
      true
    end

    # Release a previously acquired read lock.
    #
    # @return [Boolean] true if the lock is successfully released
    def release_read_lock
      while(true)
        c = @counter.value
        if @counter.compare_and_swap(c,c-1)
          # If one or more writers were waiting, and we were the last reader, wake a writer up
          if waiting_writer?(c) && running_readers(c) == 1
            @writer_mutex.synchronize { @writer_q.signal }
          end
          break
        end
      end
      true
    end

    # Acquire a write lock. Will block and wait for all active readers and writers.
    #
    # @return [Boolean] true if the lock is successfully acquired
    #
    # @raise [Concurrent::ResourceLimitError] if the maximum number of writers
    #   is exceeded.
    def acquire_write_lock
      while(true)
        c = @counter.value
        raise ResourceLimitError.new('Too many writer threads') if max_writers?(c)

        if c == 0 # no readers OR writers running
          # if we successfully swap the RUNNING_WRITER bit on, then we can go ahead
          break if @counter.compare_and_swap(0,RUNNING_WRITER)
        elsif @counter.compare_and_swap(c,c+WAITING_WRITER)
          while(true)
            # Now we have successfully incremented, so no more readers will be able to increment
            #   (they will wait instead)
            # However, readers OR writers could decrement right here, OR another writer could increment
            @writer_mutex.synchronize do
              # So we have to do another check inside the synchronized section
              # If a writer OR reader is running, then go to sleep
              c = @counter.value
              @writer_q.wait(@writer_mutex) if running_writer?(c) || running_readers?(c)
            end

            # We just came out of a wait
            # If we successfully turn the RUNNING_WRITER bit on with an atomic swap,
            # Then we are OK to stop waiting and go ahead
            # Otherwise go back and wait again
            c = @counter.value
            break if !running_writer?(c) && !running_readers?(c) &&
              @counter.compare_and_swap(c,c+RUNNING_WRITER-WAITING_WRITER)
          end
          break
        end
      end
      true
    end

    # Release a previously acquired write lock.
    #
    # @return [Boolean] true if the lock is successfully released
    def release_write_lock
      while(true)
        c = @counter.value
        if @counter.compare_and_swap(c,c-RUNNING_WRITER)
          @reader_mutex.synchronize { @reader_q.broadcast }
          if waiting_writers(c) > 0 # if any writers are waiting...
            @writer_mutex.synchronize { @writer_q.signal }
          end
          break
        end
      end
      true
    end

    # Queries if the write lock is held by any thread.
    #
    # @return [Boolean] true if the write lock is held else false`
    def write_locked?
      @counter.value >= RUNNING_WRITER
    end

    # Queries whether any threads are waiting to acquire the read or write lock.
    #
    # @return [Boolean] true if any threads are waiting for a lock else false
    def has_waiters?
      waiting_writer?(@counter.value)
    end

    private

    # @!visibility private
    def running_readers(c = @counter.value)
      c & MAX_READERS
    end

    # @!visibility private
    def running_readers?(c = @counter.value)
      (c & MAX_READERS) > 0
    end

    # @!visibility private
    def running_writer?(c = @counter.value)
      c >= RUNNING_WRITER
    end

    # @!visibility private
    def waiting_writers(c = @counter.value)
      (c & MAX_WRITERS) / WAITING_WRITER
    end

    # @!visibility private
    def waiting_writer?(c = @counter.value)
      c >= WAITING_WRITER
    end

    # @!visibility private
    def max_readers?(c = @counter.value)
      (c & MAX_READERS) == MAX_READERS
    end

    # @!visibility private
    def max_writers?(c = @counter.value)
      (c & MAX_WRITERS) == MAX_WRITERS
    end
  end
end

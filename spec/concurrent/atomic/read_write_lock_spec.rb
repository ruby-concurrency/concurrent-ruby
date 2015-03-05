module Concurrent

  describe ReadWriteLock do

    context '#with_read_lock' do

      it 'acquires the lock'

      it 'returns the value of the block operation'

      it 'releases the lock'

      it 'raises an exception if no block is given'

      it 'raises an exception if maximum lock limit is exceeded'

      it 'does not release the lock when an exception is raised'
    end

    context '#with_write_lock' do

      it 'acquires the lock'

      it 'returns the value of the block operation'

      it 'releases the lock'

      it 'raises an exception if no block is given'

      it 'raises an exception if maximum lock limit is exceeded'

      it 'does not release the lock when an exception is raised'
    end

    context '#acquire_read_lock' do

      it 'increments the lock count'

      it 'waits for a running writer to finish'

      it 'does not wait for any running readers'

      it 'raises an exception if maximum lock limit is exceeded'
    end

    context '#release_read_lock' do

      it 'decrements the counter'

      it 'unblocks running writers'
    end

    context '#acquire_write_lock' do

      it 'increments the lock count'

      it 'waits for a running writer to finish'

      it 'waits for a running reader to finish'

      it 'raises an exception if maximum lock limit is exceeded'
    end

    context '#release_write_lock' do

      it 'decrements the counter'

      it 'unblocks running readers'

      it 'unblocks running writers'
    end

    context '#to_s' do

      it 'includes the running reader count'

      it 'includes the running writer count'

      it 'includes the waiting writer count'
    end
  end
end

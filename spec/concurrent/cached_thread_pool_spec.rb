require 'spec_helper'
require_relative 'thread_pool_shared'

module Concurrent

  describe CachedThreadPool do

    subject { CachedThreadPool.new(max_threads: 5) }

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :thread_pool

    context '#initialize' do

      it 'raises an exception when the pool size is less than one' do
        lambda {
          CachedThreadPool.new(max: 0)
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception when the pool size is greater than MAX_POOL_SIZE' do
        lambda {
          CachedThreadPool.new(max: CachedThreadPool::MAX_POOL_SIZE + 1)
        }.should raise_error(ArgumentError)
      end
    end

    context '#length' do

      it 'returns zero for a new thread pool' do
        subject.length.should eq 0
      end

      it 'returns the length of the subject when running' do
        5.times{ sleep(0.1); subject << proc{ sleep(1) } }
        subject.length.should eq 5
      end

      it 'returns zero once shut down' do
        subject.shutdown
        subject.length.should eq 0
      end
    end

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        subject.length.should eq 0
        5.times{ sleep(0.1); subject << proc{ sleep } }
        sleep(1)
        subject.length.should eq 5
      end

      it 'uses existing idle threads' do
        5.times{ subject << proc{ sleep(0.1) } }
        sleep(1)
        subject.length.should >= 5
        3.times{ subject << proc{ sleep } }
        sleep(0.1)
        subject.length.should >= 5
      end

      it 'never creates more than :max_threads threads' do
        pool = CachedThreadPool.new(max: 5)
        100.times{ sleep(0.01); pool << proc{ sleep } }
        sleep(0.1)
        pool.length.should eq 5
        pool.kill
      end

      it 'sets :max_threads to MAX_POOL_SIZE when not given' do
        CachedThreadPool.new.max_threads.should eq CachedThreadPool::MAX_POOL_SIZE
      end
    end

    context 'garbage collection' do

      subject{ CachedThreadPool.new(gc_interval: 1, idletime: 1) }

      it 'removes from pool any thread that has been idle too long' do
        3.times { subject << proc{ sleep(0.1) } }
        subject.length.should eq 3
        sleep(2)
        subject << proc{ nil }
        subject.length.should < 3
      end

      it 'removed from pool any dead thread' do
        3.times { subject << proc{ sleep(0.1); raise Exception } }
        subject.length.should == 3
        sleep(2)
        subject << proc{ nil }
        subject.length.should < 3
      end
    end
  end
end

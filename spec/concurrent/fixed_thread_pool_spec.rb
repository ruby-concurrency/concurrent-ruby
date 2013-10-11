require 'spec_helper'
require_relative 'thread_pool_shared'

module Concurrent

  describe FixedThreadPool do

    subject { FixedThreadPool.new(5) }

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :thread_pool

    context '#initialize' do

      it 'raises an exception when the pool size is less than one' do
        lambda {
          FixedThreadPool.new(0)
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception when the pool size is greater than MAX_POOL_SIZE' do
        lambda {
          FixedThreadPool.new(FixedThreadPool::MAX_POOL_SIZE + 1)
        }.should raise_error(ArgumentError)
      end
    end

    context '#size' do

      let(:pool_size) { 3 }
      subject { FixedThreadPool.new(pool_size) }

      it 'returns zero on start' do
        subject.shutdown
        subject.size.should eq 0
      end

      it 'returns the size of the pool when running' do
        pool_size.times do |i|
          subject.post{ sleep }
          sleep(0.1)
          subject.size.should eq pool_size
        end
      end

      it 'returns zero while shutting down' do
        subject.post{ sleep(1) }
        subject.shutdown
        subject.size.should eq 0
      end

      it 'returns zero once shut down' do
        subject.shutdown
        subject.size.should eq 0
      end
    end

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        pool = FixedThreadPool.new(5)
        pool.size.should eq 0
        5.times{ sleep(0.1); pool << proc{ sleep } }
        sleep(0.1)
        pool.size.should eq 5
        pool.kill
      end

      it 'never creates more than :max_threads threads' do
        pool = FixedThreadPool.new(5)
        100.times{ sleep(0.01); pool << proc{ sleep } }
        sleep(0.1)
        pool.length.should eq 5
        pool.kill
      end
    end

    context 'exception handling' do

      it 'restarts threads that experience exception' do
        pool = FixedThreadPool.new(5)
        5.times{ pool << proc{ raise StandardError } }
        sleep(5)
        pool.size.should eq 5
        pool.status.should_not include(nil)
      end
    end
  end
end

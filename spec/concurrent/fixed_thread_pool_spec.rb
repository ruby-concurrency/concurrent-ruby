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

      it 'raises an exception when the pool length is less than one' do
        lambda {
          FixedThreadPool.new(0)
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception when the pool length is greater than MAX_POOL_SIZE' do
        lambda {
          FixedThreadPool.new(FixedThreadPool::MAX_POOL_SIZE + 1)
        }.should raise_error(ArgumentError)
      end
    end

    context '#length' do

      let(:pool_length) { 3 }
      subject { FixedThreadPool.new(pool_length) }

      it 'returns zero on start' do
        subject.shutdown
        subject.length.should eq 0
      end

      it 'returns the length of the pool when running' do
        pool_length.times do |i|
          subject.post{ sleep }
          sleep(0.1)
          subject.length.should eq pool_length
        end
      end

      it 'returns zero while shutting down' do
        subject.post{ sleep(1) }
        subject.shutdown
        subject.length.should eq 0
      end

      it 'returns zero once shut down' do
        subject.shutdown
        subject.length.should eq 0
      end
    end

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        pool = FixedThreadPool.new(5)
        pool.length.should eq 0
        5.times{ pool << proc{ sleep } }
        sleep(0.1)
        pool.length.should eq 5
        pool.kill
      end

      it 'never creates more than :max_threads threads' do
        pool = FixedThreadPool.new(5)
        100.times{ pool << proc{ sleep } }
        sleep(0.1)
        pool.length.should eq 5
        pool.kill
      end
    end

    context 'exception handling' do

      it 'restarts threads that experience exception' do
        pending
        pool = FixedThreadPool.new(5)
        5.times{ pool << proc{ raise StandardError } }
        sleep(1)
        pool.length.should eq 5
      end
    end
  end
end

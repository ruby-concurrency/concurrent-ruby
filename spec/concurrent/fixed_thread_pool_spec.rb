require 'spec_helper'
require_relative 'thread_pool_shared'

module Concurrent

  describe FixedThreadPool do

    subject { FixedThreadPool.new(5) }

    after(:each) do
      subject.kill
    end

    it_should_behave_like :thread_pool

    context '#initialize' do

      it 'raises an exception when the pool size is less than one' do
        lambda {
          FixedThreadPool.new(0)
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception when the pool size is greater than 1024' do
        lambda {
          FixedThreadPool.new(1025)
        }.should raise_error(ArgumentError)
      end

      it 'creates a thread pool of the given size' do
        thread = Thread.new{ nil }
        # add one for the garbage collector
        Thread.should_receive(:new).at_least(1).times.and_return(thread)
        pool = FixedThreadPool.new(5)
        pool.size.should eq 5
      end

      it 'aliases Concurrent#new_fixed_thread_pool' do
        pool = Concurrent.new_fixed_thread_pool(5)
        pool.should be_a(FixedThreadPool)
        pool.size.should eq 5
      end
    end

    context '#kill' do

      it 'kills all threads' do
        Thread.should_receive(:kill).at_least(5).times
        pool = FixedThreadPool.new(5)
        pool.kill
        sleep(0.1)
      end
    end

    context '#size' do

      let(:pool_size) { 3 }
      subject { FixedThreadPool.new(pool_size) }

      it 'returns the size of the subject when running' do
        subject.size.should eq pool_size
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

    context 'exception handling' do

      it 'restarts threads that experience exception' do
        pool = FixedThreadPool.new(5)
        3.times{ pool << proc{ raise StandardError } }
        sleep(5)
        pool.size.should eq 5
        pool.status.should_not include(nil)
      end
    end
  end
end

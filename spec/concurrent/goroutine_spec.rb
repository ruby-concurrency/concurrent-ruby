require 'spec_helper'

module Concurrent

  describe '#go' do

    before(:each) do
      $GLOBAL_THREAD_POOL = CachedThreadPool.new
    end

    it 'passes all arguments to the block' do
      @expected = nil
      go(1, 2, 3){|a, b, c| @expected = [c, b, a] }
      sleep(0.1)
      @expected.should eq [3, 2, 1]
    end

    it 'returns true if the thread is successfully created' do
      $GLOBAL_THREAD_POOL.should_receive(:post).and_return(true)
      go{ nil }.should be_true
    end

    it 'returns false if the thread cannot be created' do
      $GLOBAL_THREAD_POOL.should_receive(:post).and_return(false)
      go{ nil }.should be_false
    end

    it 'immediately returns false if no block is given' do
      go().should be_false
    end

    it 'does not create a thread if no block is given' do
      $GLOBAL_THREAD_POOL.should_not_receive(:post)
      go()
      sleep(0.1)
    end

    it 'supresses exceptions on the thread' do
      lambda{
        go{ raise StandardError }
        sleep(0.1)
      }.should_not raise_error
    end

    it 'processes the block' do
      @expected = false
      go(1,2,3){|*args| @expected = args }
      sleep(0.1)
      @expected.should eq [1,2,3]
    end
  end
end

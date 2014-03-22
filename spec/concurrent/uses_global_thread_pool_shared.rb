require 'spec_helper'

share_examples_for Concurrent::UsesGlobalThreadPool do

  before(:each) do
    $GLOBAL_THREAD_POOL = Concurrent::NullThreadPool.new
  end

  it 'defaults to the global thread pool' do
    clazz = Class.new(thread_pool_user)
    clazz.thread_pool.should eq $GLOBAL_THREAD_POOL
  end

  it 'sets and gets the thread pool for the class' do
    pool = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool = pool
    thread_pool_user.thread_pool.should eq pool
  end

  it 'gives each class its own thread pool' do
    subject1 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }
    subject2 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }
    subject3 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }

    subject1.thread_pool = Concurrent::NullThreadPool.new
    subject2.thread_pool = Concurrent::NullThreadPool.new
    subject3.thread_pool = Concurrent::NullThreadPool.new

    subject1.thread_pool.should_not eq subject2.thread_pool
    subject2.thread_pool.should_not eq subject3.thread_pool
    subject3.thread_pool.should_not eq subject1.thread_pool
  end

  it 'uses the new global thread pool after the global thread pool is changed' do
    null_thread_pool = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool = $GLOBAL_THREAD_POOL

    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL
    thread_pool_user.thread_pool.should_not eq null_thread_pool

    $GLOBAL_THREAD_POOL = null_thread_pool

    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL
    thread_pool_user.thread_pool.should eq null_thread_pool
  end

  it 'responds to multiple changes in the global thread pool' do
    thread_pool_user.thread_pool = $GLOBAL_THREAD_POOL
    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL

    thread_pool_user.thread_pool = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool.should_not eq $GLOBAL_THREAD_POOL

    $GLOBAL_THREAD_POOL = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool = $GLOBAL_THREAD_POOL
    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL

    $GLOBAL_THREAD_POOL = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL

    $GLOBAL_THREAD_POOL = Concurrent::NullThreadPool.new
    thread_pool_user.thread_pool.should eq $GLOBAL_THREAD_POOL
  end
end

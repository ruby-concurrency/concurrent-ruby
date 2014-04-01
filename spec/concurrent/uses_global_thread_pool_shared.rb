require 'spec_helper'

share_examples_for Concurrent::UsesGlobalThreadPool do

  before(:each) do
    Concurrent.configuration.global_task_pool = Concurrent::PerThreadExecutor.new
  end

  it 'defaults to the global thread pool' do
    clazz = Class.new(thread_pool_user)
    clazz.thread_pool.should eq Concurrent.configuration.global_task_pool
  end

  it 'sets and gets the thread pool for the class' do
    pool = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool = pool
    thread_pool_user.thread_pool.should eq pool
  end

  it 'gives each class its own thread pool' do
    subject1 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }
    subject2 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }
    subject3 = Class.new(thread_pool_user){ include Concurrent::UsesGlobalThreadPool }

    subject1.thread_pool = Concurrent::PerThreadExecutor.new
    subject2.thread_pool = Concurrent::PerThreadExecutor.new
    subject3.thread_pool = Concurrent::PerThreadExecutor.new

    subject1.thread_pool.should_not eq subject2.thread_pool
    subject2.thread_pool.should_not eq subject3.thread_pool
    subject3.thread_pool.should_not eq subject1.thread_pool
  end

  it 'uses the new global thread pool after the global thread pool is changed' do
    per_thread_executor = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool = Concurrent.configuration.global_task_pool

    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool
    thread_pool_user.thread_pool.should_not eq per_thread_executor

    Concurrent.configuration.global_task_pool = per_thread_executor

    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool
    thread_pool_user.thread_pool.should eq per_thread_executor
  end

  it 'responds to multiple changes in the global thread pool' do
    thread_pool_user.thread_pool = Concurrent.configuration.global_task_pool
    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool

    thread_pool_user.thread_pool = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool.should_not eq Concurrent.configuration.global_task_pool

    Concurrent.configuration.global_task_pool = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool = Concurrent.configuration.global_task_pool
    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool

    Concurrent.configuration.global_task_pool = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool

    Concurrent.configuration.global_task_pool = Concurrent::PerThreadExecutor.new
    thread_pool_user.thread_pool.should eq Concurrent.configuration.global_task_pool
  end
end

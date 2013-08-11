require 'spec_helper'

module Concurrent

  describe UsesGlobalThreadPool do

    before(:each) do
      $GLOBAL_THREAD_POOL = FixedThreadPool.new(1)
    end

    it 'defaults to the global thread pool' do
      clazz = Class.new{ include UsesGlobalThreadPool }
      clazz.thread_pool.should eq $GLOBAL_THREAD_POOL
    end

    it 'sets and gets the thread pool for the class' do
      pool = NullThreadPool.new
      clazz = Class.new{ include UsesGlobalThreadPool }

      clazz.thread_pool = pool
      clazz.thread_pool.should eq pool
    end

    it 'gives each class its own thread pool' do
      clazz1 = Class.new{ include UsesGlobalThreadPool }
      clazz2 = Class.new{ include UsesGlobalThreadPool }
      clazz3 = Class.new{ include UsesGlobalThreadPool }

      clazz1.thread_pool = FixedThreadPool.new(1)
      clazz2.thread_pool = CachedThreadPool.new
      clazz3.thread_pool = NullThreadPool.new

      clazz1.thread_pool.should_not eq clazz2.thread_pool
      clazz2.thread_pool.should_not eq clazz3.thread_pool
      clazz3.thread_pool.should_not eq clazz1.thread_pool
    end
  end
end

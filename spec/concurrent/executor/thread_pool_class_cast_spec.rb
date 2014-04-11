require 'spec_helper'

module Concurrent

  describe SingleThreadExecutor do
    if jruby?
      it 'inherits from JavaSingleThreadExecutor' do
        SingleThreadExecutor.ancestors.should include(JavaSingleThreadExecutor)
      end
    else
      it 'inherits from RubySingleThreadExecutor' do
        SingleThreadExecutor.ancestors.should include(RubySingleThreadExecutor)
      end
    end
  end

  describe ThreadPoolExecutor do
    if jruby?
      it 'inherits from JavaThreadPoolExecutor' do
        ThreadPoolExecutor.ancestors.should include(JavaThreadPoolExecutor)
      end
    else
      it 'inherits from RubyThreadPoolExecutor' do
        ThreadPoolExecutor.ancestors.should include(RubyThreadPoolExecutor)
      end
    end
  end

  describe CachedThreadPool do
    if jruby?
      it 'inherits from JavaCachedThreadPool' do
        CachedThreadPool.ancestors.should include(JavaCachedThreadPool)
      end
    else
      it 'inherits from RubyCachedThreadPool' do
        CachedThreadPool.ancestors.should include(RubyCachedThreadPool)
      end
    end
  end

  describe FixedThreadPool do
    if jruby?
      it 'inherits from JavaFixedThreadPool' do
        FixedThreadPool.ancestors.should include(JavaFixedThreadPool)
      end
    else
      it 'inherits from RubyFixedThreadPool' do
        FixedThreadPool.ancestors.should include(RubyFixedThreadPool)
      end
    end
  end
end

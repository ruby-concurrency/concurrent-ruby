require 'spec_helper'

if jruby?

  require_relative 'cached_thread_pool_shared'

  module Concurrent

    describe JavaCachedThreadPool do

      subject { described_class.new(max_threads: 5) }

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      it_should_behave_like :cached_thread_pool
    end
  end
end

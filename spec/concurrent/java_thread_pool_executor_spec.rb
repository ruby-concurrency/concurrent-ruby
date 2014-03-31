require 'spec_helper'

if jruby?

  require_relative 'thread_pool_shared'

  module Concurrent

    describe JavaThreadPoolExecutor do

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      subject do
        JavaThreadPoolExecutor.new(
          min_threads: 2,
          max_threads: 5,
          idletime: 1,
          max_queue: 10,
          overflow_policy: :abort
        )
      end

      it_should_behave_like :thread_pool
    end
  end
end

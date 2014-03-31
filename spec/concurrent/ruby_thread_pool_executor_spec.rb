require 'spec_helper'
require_relative 'thread_pool_executor_shared'

module Concurrent

  describe RubyThreadPoolExecutor do

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    subject do
      RubyThreadPoolExecutor.new(
        min_threads: 2,
        max_threads: 5,
        idletime: 1,
        max_queue: 10,
        overflow_policy: :abort
      )
    end

    it_should_behave_like :thread_pool_executor
  end
end

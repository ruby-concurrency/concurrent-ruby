require_relative 'executor_service_shared'
require_relative 'thread_pool_shared'

module Concurrent

  describe RubySingleThreadExecutor, :type=>:mrirbx do

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    subject { RubySingleThreadExecutor.new }
    it_behaves_like :executor_service

    subject { RubySingleThreadExecutor.new(prioritize: true) }
    it_behaves_like :prioritized_thread_pool
  end
end

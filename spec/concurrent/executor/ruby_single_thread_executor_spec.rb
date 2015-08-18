require_relative 'executor_service_shared'
require_relative 'prioritized_thread_pool_shared'

module Concurrent

  describe RubySingleThreadExecutor, :type=>:mrirbx do

    after(:each) do
      subject.kill
      subject.wait_for_termination(0.1)
    end

    subject { RubySingleThreadExecutor.new }
    it_behaves_like :executor_service

    context 'when prioritized' do
      subject { RubySingleThreadExecutor.new(prioritize: true) }
      it_behaves_like :prioritized_thread_pool
    end
  end
end

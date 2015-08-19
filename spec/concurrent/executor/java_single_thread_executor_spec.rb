if Concurrent.on_jruby?

  require_relative 'executor_service_shared'
  require_relative 'prioritized_thread_pool_shared'

  module Concurrent

    describe JavaSingleThreadExecutor, :type=>:jruby do

      after(:each) do
        subject.kill
        subject.wait_for_termination(0.1)
      end

      subject { JavaSingleThreadExecutor.new }
      it_should_behave_like :executor_service

      context 'when prioritized' do
        subject { JavaSingleThreadExecutor.new(prioritize: true) }
        it_behaves_like :prioritized_thread_pool
      end
    end
  end
end

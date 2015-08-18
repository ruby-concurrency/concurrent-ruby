if Concurrent.on_jruby?

  require_relative 'thread_pool_executor_shared'
  require_relative 'prioritized_thread_pool_shared'

  module Concurrent

    describe JavaThreadPoolExecutor, :type => :jruby do

      after(:each) do
        subject.kill
        subject.wait_for_termination(0.1)
      end

      subject do
        described_class.new(
          min_threads: 2,
          max_threads: 5,
          idletime: 60,
          max_queue: 10,
          fallback_policy: :discard
        )
      end

      it_should_behave_like :thread_pool

      it_should_behave_like :thread_pool_executor

      context 'when prioritized' do
        subject { described_class.new(min_threads: 1, max_threads: 1, prioritize: true) }
        it_behaves_like :prioritized_thread_pool
      end

      context '#overload_policy' do

        specify ':abort maps to AbortPolicy' do
          clazz = java.util.concurrent.ThreadPoolExecutor::AbortPolicy
          policy = clazz.new
          expect(clazz).to receive(:new).at_least(:once).with(any_args).and_return(policy)
          described_class.new(
            min_threads: 2,
            max_threads: 5,
            idletime: 60,
            max_queue: 10,
            fallback_policy: :abort
          )
        end

        specify ':discard maps to DiscardPolicy' do
          clazz = java.util.concurrent.ThreadPoolExecutor::DiscardPolicy
          policy = clazz.new
          expect(clazz).to receive(:new).at_least(:once).with(any_args).and_return(policy)
          described_class.new(
            min_threads: 2,
            max_threads: 5,
            idletime: 60,
            max_queue: 10,
            fallback_policy: :discard
          )
        end

        specify ':caller_runs maps to CallerRunsPolicy' do
          clazz = java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
          policy = clazz.new
          expect(clazz).to receive(:new).at_least(:once).with(any_args).and_return(policy)
          described_class.new(
            min_threads: 2,
            max_threads: 5,
            idletime: 60,
            max_queue: 10,
            fallback_policy: :caller_runs
          )
        end
      end
    end
  end
end

require_relative 'thread_pool_executor_shared'
require_relative 'prioritized_thread_pool_shared'

module Concurrent

  describe RubyThreadPoolExecutor, :type=>:mrirbx do

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

    context '#remaining_capacity' do

      let!(:expected_max){ 100 }

      subject do
        described_class.new(
          min_threads: 10,
          max_threads: 20,
          idletime: 60,
          max_queue: expected_max,
          fallback_policy: :discard
        )
      end

      it 'returns :max_length when no tasks are enqueued' do
        5.times{ subject.post{ nil } }
        sleep(0.1)
        expect(subject.remaining_capacity).to eq expected_max
      end

      it 'returns the remaining capacity when tasks are enqueued' do
        100.times{ subject.post{ sleep(0.5) } }
        sleep(0.1)
        expect(subject.remaining_capacity).to be < expected_max
      end
    end
  end
end

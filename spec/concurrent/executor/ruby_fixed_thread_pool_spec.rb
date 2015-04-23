require_relative 'fixed_thread_pool_shared'

module Concurrent

  describe RubyFixedThreadPool, :type=> :mrirbx do

    subject { described_class.new(5, fallback_policy: :discard) }

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :fixed_thread_pool

    context 'exception handling' do

      it 'restarts threads that experience exception' do
        count = subject.length
        count.times{ subject << proc{ raise StandardError } }
        sleep(1)
        expect(subject.length).to eq count
      end
    end

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        pool = described_class.new(5)
        expect(pool.length).to eq 0
        5.times{ pool << proc{ sleep(1) } }
        sleep(0.1)
        expect(pool.length).to eq 5
        pool.kill
      end
    end
  end
end

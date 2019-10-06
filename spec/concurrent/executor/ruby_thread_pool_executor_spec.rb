require_relative 'thread_pool_executor_shared'

module Concurrent

  RSpec.describe RubyThreadPoolExecutor, :type=>:mrirbx do

    after(:each) do
      subject.shutdown
      expect(subject.wait_for_termination(pool_termination_timeout)).to eq true
    end

    subject do
      RubyThreadPoolExecutor.new(
        min_threads: 2,
        max_threads: 5,
        idletime: 60,
        max_queue: 10,
        fallback_policy: :discard
      )
    end

    it_should_behave_like :thread_pool

    it_should_behave_like :thread_pool_executor

    context '#remaining_capacity' do

      let!(:expected_max){ 100 }
      let(:latch) { Concurrent::CountDownLatch.new }

      subject do
        RubyThreadPoolExecutor.new(
          min_threads: 10,
          max_threads: 20,
          idletime: 60,
          max_queue: expected_max,
          fallback_policy: :discard
        )
      end

      it 'returns :max_length when no tasks are enqueued' do
        5.times{ subject.post{ nil } }
        subject.post { latch.count_down }
        latch.wait(0.1)
        expect(subject.remaining_capacity).to eq expected_max
      end

      it 'returns the remaining capacity when tasks are enqueued' do
        block = Concurrent::CountDownLatch.new
        100.times{ subject.post{ block.wait } }
        subject.post { latch.count_down }
        latch.wait(0.1)
        expect(subject.remaining_capacity).to be < expected_max
        block.count_down
      end
    end

    context 'threads naming' do
      subject do
        opts = { min_threads: 2 }
        opts[:name] = pool_name if pool_name
        described_class.new(opts)
      end

      let(:names) { Concurrent::Set.new }

      before do
        subject.post(names) { |names| names << Thread.current.name }
        subject.post(names) { |names| names << Thread.current.name }
        subject.shutdown
        subject.wait_for_termination(pool_termination_timeout)
        expect(names.size).to eq 2
      end

      context 'without pool name' do
        let(:pool_name) { }
        it 'sets counted name' do
          expect(names.all? { |name| name =~ /^Concurrent.*Worker-\d+$/ }).to be true
        end
      end

      context 'with pool name' do
        let(:pool_name) { 'MyExecutor' }
        it 'sets counted name' do
          expect(names.all? { |name| name =~ /^MyExecutor-Concurrent.*Worker-\d+$/ }).to be true
        end
      end
    end
  end
end

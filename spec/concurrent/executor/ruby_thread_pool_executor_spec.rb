require 'spec_helper'
require_relative 'thread_pool_executor_shared'

module Concurrent

  describe RubyThreadPoolExecutor, :type=>:mrirbx do

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    subject do
      RubyThreadPoolExecutor.new(
        min_threads: 2,
        max_threads: 5,
        idletime: 60,
        max_queue: 10,
        overflow_policy: :discard
      )
    end

    it_should_behave_like :thread_pool_executor

    context '#remaining_capacity' do

      let!(:expected_max){ 100 }

      subject do
        RubyThreadPoolExecutor.new(
          min_threads: 10,
          max_threads: 20,
          idletime: 60,
          max_queue: expected_max,
          overflow_policy: :discard
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

    context '#overload_policy' do

      let!(:min_threads){ 1 }
      let!(:max_threads){ 1 }
      let!(:idletime){ 60 }
      let!(:max_queue){ 1 }

      context ':abort' do

        subject do
          described_class.new(
            min_threads: min_threads,
            max_threads: max_threads,
            idletime: idletime,
            max_queue: max_queue,
            overflow_policy: :abort
          )
        end

        specify '#post raises an error when the queue is at capacity' do
          expect {
            100.times{ subject.post{ sleep(1) } }
          }.to raise_error(Concurrent::RejectedExecutionError)
        end

        specify '#<< raises an error when the queue is at capacity' do
          expect {
            100.times{ subject << proc { sleep(1) } }
          }.to raise_error(Concurrent::RejectedExecutionError)
        end

        specify 'a #post task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          10.times do
            begin
              subject.post{ executed.increment; sleep(0.1) }
            rescue
            end
          end
          sleep(0.2)
          expect(executed.value).to be < 10
        end

        specify 'a #<< task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          10.times do
            begin
              subject << proc { executed.increment; sleep(0.1) }
            rescue
            end
          end
          sleep(0.2)
          expect(executed.value).to be < 10
        end
      end

      context ':discard' do

        subject do
          described_class.new(
            min_threads: min_threads,
            max_threads: max_threads,
            idletime: idletime,
            max_queue: max_queue,
            overflow_policy: :discard
          )
        end

        specify 'a #post task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          1000.times do
            subject.post{ executed.increment }
          end
          sleep(0.1)
          expect(executed.value).to be < 1000
        end

        specify 'a #<< task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          1000.times do
            subject << proc { executed.increment }
          end
          sleep(0.1)
          expect(executed.value).to be < 1000
        end
      end

      context ':caller_runs' do

        subject do
          described_class.new(
            min_threads: 1,
            max_threads: 1,
            idletime: idletime,
            max_queue: 1,
            overflow_policy: :caller_runs
          )
        end

        specify '#post does not create any new threads when the queue is at capacity' do
          initial = Thread.list.length
          5.times{ subject.post{ sleep(0.1) } }
          expect(Thread.list.length).to be < initial + 5
        end

        specify '#<< executes the task on the current thread when the queue is at capacity' do
          expect(subject).to receive(:handle_overflow).with(any_args).at_least(:once)
          5.times{ subject << proc { sleep(0.1) } }
        end

        specify '#post executes the task on the current thread when the queue is at capacity' do
          latch = Concurrent::CountDownLatch.new(5)
          subject.post{ sleep(1) }
          5.times{|i| subject.post{ latch.count_down } }
          latch.wait(0.1)
        end
      end
    end
  end
end

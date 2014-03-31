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
        idletime: 60,
        max_queue: 10,
        overflow_policy: :discard
      )
    end

    it_should_behave_like :thread_pool_executor

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
          100.times do
            begin
              subject.post{ executed.increment }
            rescue
            end
          end
          sleep(0.1)
          executed.value.should < 100
        end

        specify 'a #<< task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          100.times do
            begin
              subject << proc { executed.increment }
            rescue
            end
          end
          sleep(0.1)
          executed.value.should < 100
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
          100.times do
            subject.post{ executed.increment }
          end
          sleep(0.1)
          executed.value.should < 100
        end

        specify 'a #<< task is never executed when the queue is at capacity' do
          executed = Concurrent::AtomicFixnum.new(0)
          100.times do
            subject << proc { executed.increment }
          end
          sleep(0.1)
          executed.value.should < 100
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
          2.times{ subject.post{ sleep(1) } }
          sleep(0.1)
          expected = Thread.list.length
          subject.post{ nil }
          Thread.list.length.should eq expected
        end

        specify '#post executes the task on the current thread when the queue is at capacity' do
          2.times{ subject.post{ sleep(1) } }
          sleep(0.1)
          expected = false
          subject.post{ expected = true }
          expected.should be_true
        end

        specify '#<< executes the task on the current thread when the queue is at capacity' do
          2.times{ subject.post{ sleep(1) } }
          sleep(0.1)
          expected = false
          subject << proc { expected = true }
          expected.should be_true
        end
      end
    end
  end
end

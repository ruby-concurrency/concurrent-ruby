require 'spec_helper'
require_relative 'thread_pool_shared'

shared_examples :thread_pool_executor do


  after(:each) do
    subject.kill
    sleep(0.1)
  end

  context '#initialize defaults' do

    subject { described_class.new }

    it 'defaults :min_length to DEFAULT_MIN_POOL_SIZE' do
      expect(subject.min_length).to eq described_class::DEFAULT_MIN_POOL_SIZE
    end


    it 'defaults :max_length to DEFAULT_MAX_POOL_SIZE' do
      expect(subject.max_length).to eq described_class::DEFAULT_MAX_POOL_SIZE
    end

    it 'defaults :idletime to DEFAULT_THREAD_IDLETIMEOUT' do
      expect(subject.idletime).to eq described_class::DEFAULT_THREAD_IDLETIMEOUT
    end

    it 'defaults :max_queue to DEFAULT_MAX_QUEUE_SIZE' do
      expect(subject.max_queue).to eq described_class::DEFAULT_MAX_QUEUE_SIZE
    end

    it 'defaults :fallback_policy to :abort' do
      expect(subject.fallback_policy).to eq :abort
    end
  end

  context "#initialize explicit values" do

    it "sets :min_threads" do
      expect(described_class.new(min_threads: 2).min_length).to eq 2
    end

    it "sets :max_threads" do
      expect(described_class.new(max_threads: 2).max_length).to eq 2
    end

    it "sets :idletime" do
      expect(described_class.new(idletime: 2).idletime).to eq 2
    end

    it "doesn't allow max_threads < min_threads" do
      expect {
        described_class.new(min_threads: 2, max_threads: 1)
      }.to raise_error(ArgumentError)
    end

    it 'accepts all valid fallback policies' do
      Concurrent::RubyThreadPoolExecutor::FALLBACK_POLICIES.each do |policy|
        subject = described_class.new(fallback_policy: policy)
        expect(subject.fallback_policy).to eq policy
      end
    end


    it 'raises an exception if :min_threads is less than zero' do
      expect {
        described_class.new(min_threads: -1)
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception if :max_threads is not greater than zero' do
      expect {
        described_class.new(max_threads: 0)
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception if given an invalid :fallback_policy' do
      expect {
        described_class.new(fallback_policy: :bogus)
      }.to raise_error(ArgumentError)
    end
  end

  context '#max_queue' do

    let!(:expected_max){ 100 }
    subject{ described_class.new(max_queue: expected_max) }

    it 'returns the set value on creation' do
      expect(subject.max_queue).to eq expected_max
    end

    it 'returns the set value when running' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      expect(subject.max_queue).to eq expected_max
    end

    it 'returns the set value after stopping' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.max_queue).to eq expected_max
    end
  end

  context '#queue_length' do

    let!(:expected_max){ 10 }
    subject do
      described_class.new(
        min_threads: 2,
        max_threads: 5,
        max_queue: expected_max,
        fallback_policy: :discard
      )
    end

    it 'returns zero on creation' do
      expect(subject.queue_length).to eq 0
    end

    it 'returns zero when there are no enqueued tasks' do
      5.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.queue_length).to eq 0
    end

    it 'returns the size of the queue when tasks are enqueued' do
      100.times{ subject.post{ sleep(0.5) } }
      sleep(0.1)
      expect(subject.queue_length).to be > 0
    end

    it 'returns zero when stopped' do
      100.times{ subject.post{ sleep(0.5) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.queue_length).to eq 0
    end

    it 'can never be greater than :max_queue' do
      100.times{ subject.post{ sleep(0.5) } }
      sleep(0.1)
      expect(subject.queue_length).to be <= expected_max
    end
  end

  context '#remaining_capacity' do

    let!(:expected_max){ 100 }
    subject{ described_class.new(max_queue: expected_max) }

    it 'returns -1 when :max_queue is set to zero' do
      executor = described_class.new(max_queue: 0)
      expect(executor.remaining_capacity).to eq -1
    end

    it 'returns :max_length on creation' do
      expect(subject.remaining_capacity).to eq expected_max
    end

    it 'returns :max_length when stopped' do
      100.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.remaining_capacity).to eq expected_max
    end
  end
  
  context '#fallback_policy' do

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
          fallback_policy: :abort
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

      specify '#post raises an error when the executor is shutting down' do
        expect {
          subject.shutdown; subject.post{ sleep(1) }
        }.to raise_error(Concurrent::RejectedExecutionError)
      end

      specify '#<< raises an error when the executor is shutting down' do
        expect {
          subject.shutdown; subject << proc { sleep(1) }
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
          fallback_policy: :discard
        )
      end

      specify 'a #post task is never executed when the queue is at capacity' do
        lock = Mutex.new
        lock.lock

        latch = Concurrent::CountDownLatch.new(max_threads)
        
        initial_executed = Concurrent::AtomicFixnum.new(0)
        subsequent_executed = Concurrent::AtomicFixnum.new(0)

        # Fill up all the threads (with a task that won't run until
        # lock.unlock is called)
        max_threads.times do
          subject.post{ latch.count_down; lock.lock; initial_executed.increment; lock.unlock }
        end

        # Wait for all those tasks to be taken off the queue onto a
        # worker thread and start executing
        latch.wait
        
        # Fill up the queue (with a task that won't run until
        # lock.unlock is called)
        max_queue.times do
          subject.post{ lock.lock; initial_executed.increment; lock.unlock }
        end

        # Inject 100 more tasks, which should be dropped without an exception
        100.times do
          subject.post{ subsequent_executed.increment; }
        end

        # Unlock the lock, so that the tasks in the threads and on
        # the queue can run to completion
        lock.unlock

        # Wait for all tasks to finish
        subject.shutdown
        subject.wait_for_termination

        # The tasks should have run until all the threads and the
        # queue filled up...
        expect(initial_executed.value).to be (max_threads + max_queue)

        # ..but been dropped after that
        expect(subsequent_executed.value).to be 0
      end

      specify 'a #<< task is never executed when the queue is at capacity' do
        executed = Concurrent::AtomicFixnum.new(0)
        1000.times do
          subject << proc { sleep; executed.increment }
        end
        sleep(0.1)
        expect(executed.value).to be 0
      end

      specify 'a #post task is never executed when the executor is shutting down' do
        executed = Concurrent::AtomicFixnum.new(0)
        subject.shutdown
        subject.post{ sleep; executed.increment }
        sleep(0.1)
        expect(executed.value).to be 0
      end

      specify 'a #<< task is never executed when the executor is shutting down' do
        executed = Concurrent::AtomicFixnum.new(0)
        subject.shutdown
        subject << proc { executed.increment }
        sleep(0.1)
        expect(executed.value).to be 0
      end

      specify '#post returns false when the executor is shutting down' do
        executed = Concurrent::AtomicFixnum.new(0)
        subject.shutdown
        ret = subject.post{ executed.increment }
        expect(ret).to be false
      end
    end

    context ':caller_runs' do

      subject do
        described_class.new(
          min_threads: 1,
          max_threads: 1,
          idletime: idletime,
          max_queue: 1,
          fallback_policy: :caller_runs
        )
      end

      specify '#post does not create any new threads when the queue is at capacity' do
        initial = Thread.list.length
        5.times{ subject.post{ sleep(0.1) } }
        expect(Thread.list.length).to be < initial + 5
      end

      specify '#<< executes the task on the current thread when the queue is at capacity' do
        latch = Concurrent::CountDownLatch.new(5)
        subject.post{ sleep(1) }
        5.times{|i| subject << proc { latch.count_down } }
        latch.wait(0.1)
      end

      specify '#post executes the task on the current thread when the queue is at capacity' do
        latch = Concurrent::CountDownLatch.new(5)
        subject.post{ sleep(1) }
        5.times{|i| subject.post{ latch.count_down } }
        latch.wait(0.1)
      end

      specify '#post executes the task on the current thread when the executor is shutting down' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.shutdown
        subject.post{ latch.count_down }
        latch.wait(0.1)
      end

      specify '#<< executes the task on the current thread when the executor is shutting down' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.shutdown
        subject << proc { latch.count_down }
        latch.wait(0.1)
      end
    end
  end

  context '#overflow_policy' do
    context ':caller_runs is honoured even if the old overflow_policy arg is used' do

      subject do
        described_class.new(
          min_threads: 1,
          max_threads: 1,
          idletime: 60,
          max_queue: 1,
          overflow_policy: :caller_runs
        )
      end

      specify '#<< executes the task on the current thread when the executor is shutting down' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.shutdown
        subject << proc { latch.count_down }
        latch.wait(0.1)
      end
    end
  end
end

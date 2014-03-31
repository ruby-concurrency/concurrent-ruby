require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :thread_pool_executor do

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#initialize' do

    it 'defaults :min_length to DEFAULT_MIN_POOL_SIZE' do
      subject = described_class.new
      subject.min_length.should eq described_class::DEFAULT_MIN_POOL_SIZE
    end

    it 'defaults :max_length to DEFAULT_MAX_POOL_SIZE' do
      subject = described_class.new
      subject.max_length.should eq described_class::DEFAULT_MAX_POOL_SIZE
    end

    it 'defaults :idletime to DEFAULT_THREAD_IDLETIMEOUT' do
      subject = described_class.new
      subject.idletime.should eq described_class::DEFAULT_THREAD_IDLETIMEOUT
    end

    it 'defaults :max_queue to DEFAULT_MAX_QUEUE_SIZE' do
      subject = described_class.new
      subject.max_queue.should eq described_class::DEFAULT_MAX_QUEUE_SIZE
    end

    it 'defaults :overflow_policy to :abort' do
      subject = described_class.new
      subject.overflow_policy.should eq :abort
    end
  end

  context '#max_queue' do

    let!(:expected_max){ 100 }
    subject{ described_class.new(max_queue: expected_max) }

    it 'returns the set value on creation' do
      subject.max_queue.should eq expected_max
    end

    it 'returns the set value when running' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.max_queue.should eq expected_max
    end

    it 'returns the set value after stopping' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.max_queue.should eq expected_max
    end
  end

  context '#queue_length' do

    it 'returns zero on creation' do
      subject.queue_length.should eq 0
    end

    it 'returns zero when there are no enqueued tasks' do
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.queue_length.should eq 0
    end

    it 'returns the size of the queue when tasks are enqueued' do
      100.times{ subject.post{ sleep(0.5) } }
      sleep(0.1)
      subject.queue_length.should > 0
    end

    it 'returns zero when stopped' do
      100.times{ subject.post{ sleep(0.5) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.queue_length.should eq 0
    end
  end

  context '#remaining_capacity' do

    let!(:expected_max){ 100 }
    subject{ described_class.new(max_queue: expected_max) }

    it 'returns -1 when :max_queue is set to zero' do
      executor = described_class.new(max_queue: 0)
      executor.remaining_capacity.should eq -1
    end

    it 'returns :max_length on creation' do
      subject.remaining_capacity.should eq expected_max
    end

    it 'returns :max_length when no tasks are enqueued' do
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.remaining_capacity.should eq eq expected_max
    end

    it 'returns the remaining capacity when tasks are enqueued' do
      100.times{ subject.post{ sleep(0.5) } }
      subject.remaining_capacity.should < expected_max
    end

    it 'returns :max_length when stopped' do
      100.times{ subject.post{ sleep(0.5) } }
      subject.shutdown
      subject.wait_for_termination(1)
      subject.remaining_capacity.should eq expected_max
    end
  end

  context '#overload_policy' do
    pending
  end
end

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

    it 'defaults :overflow_policy to :abort' do
      expect(subject.overflow_policy).to eq :abort
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

    it 'accepts all valid overflow policies' do
      Concurrent::RubyThreadPoolExecutor::OVERFLOW_POLICIES.each do |policy|
        subject = described_class.new(overflow_policy: policy)
        expect(subject.overflow_policy).to eq policy
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

    it 'raises an exception if given an invalid :overflow_policy' do
      expect {
        described_class.new(overflow_policy: :bogus)
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
        overflow_policy: :discard
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
end

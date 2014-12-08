require 'spec_helper'
require_relative 'thread_pool_shared'

shared_examples :cached_thread_pool do

  subject do
    described_class.new(fallback_policy: :discard)
  end

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#initialize' do

    it 'sets :max_length to DEFAULT_MAX_POOL_SIZE' do
      expect(described_class.new.max_length).to eq described_class::DEFAULT_MAX_POOL_SIZE
    end

    it 'sets :min_length to DEFAULT_MIN_POOL_SIZE' do
      subject = expect(described_class.new.min_length).to eq described_class::DEFAULT_MIN_POOL_SIZE
    end

    it 'sets :idletime to DEFAULT_THREAD_IDLETIMEOUT' do
      subject = expect(described_class.new.idletime).to eq described_class::DEFAULT_THREAD_IDLETIMEOUT
    end

    it 'sets :max_queue to DEFAULT_MAX_QUEUE_SIZE' do
      subject = expect(described_class.new.max_queue).to eq described_class::DEFAULT_MAX_QUEUE_SIZE
    end
  end

  context '#min_length' do

    it 'returns zero on creation' do
      expect(subject.min_length).to eq 0
    end

    it 'returns zero while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.min_length).to eq 0
    end

    it 'returns zero once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.min_length).to eq 0
    end
  end

  context '#max_length' do

    it 'returns :max_length on creation' do
      expect(subject.max_length).to eq described_class::DEFAULT_MAX_POOL_SIZE
    end

    it 'returns :max_length while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.max_length).to eq described_class::DEFAULT_MAX_POOL_SIZE
    end

    it 'returns :max_length once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.max_length).to eq described_class::DEFAULT_MAX_POOL_SIZE
    end
  end

  context '#largest_length' do

    it 'returns zero on creation' do
      expect(subject.largest_length).to eq 0
    end

    it 'returns a non-zero number once tasks have been received' do
      10.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      expect(subject.largest_length).to be > 0
    end

    it 'returns a non-zero number after shutdown if tasks have been received' do
      10.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.largest_length).to be > 0
    end
  end

  context '#status' do

    it 'returns an array' do
      allow(subject).to receive(:warn)
      expect(subject.status).to be_kind_of(Array)
    end
  end

  context '#idletime' do

    subject{ described_class.new(idletime: 42) }

    it 'returns the thread idletime' do
      expect(subject.idletime).to eq described_class::DEFAULT_THREAD_IDLETIMEOUT
    end
  end
end

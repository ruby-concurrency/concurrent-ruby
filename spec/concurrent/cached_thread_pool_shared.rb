require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :cached_thread_pool do

  let!(:max_threads){ 5 }
  subject { described_class.new(max_threads: max_threads) }

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#initialize' do

    it 'raises an exception when the pool idletime is less than one' do
      lambda {
        described_class.new(idletime: 0)
      }.should raise_error(ArgumentError)
    end

    it 'raises an exception when the pool size is less than one' do
      lambda {
        described_class.new(max_threads: 0)
      }.should raise_error(ArgumentError)
    end

    it 'sets :max_length to DEFAULT_MAX_POOL_SIZE when not given' do
      described_class.new.max_length.should eq described_class::DEFAULT_MAX_POOL_SIZE
    end
  end

  context '#min_length' do

    it 'returns zero on creation' do
      subject.min_length.should eq 0
    end

    it 'returns zero while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.min_length.should eq 0
    end

    it 'returns zero once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.min_length.should eq 0
    end
  end

  context '#max_length' do

    it 'returns :max_length on creation' do
      subject.max_length.should eq max_threads
    end

    it 'returns :max_length while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.max_length.should eq max_threads
    end

    it 'returns :max_length once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.max_length.should eq max_threads
    end
  end

  context '#largest_length' do

    it 'returns zero on creation' do
      subject.largest_length.should eq 0
    end

    it 'returns a non-zero number once tasks have been received' do
      10.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.largest_length.should > 0
    end

    it 'returns a non-zero number after shutdown if tasks have been received' do
      10.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.largest_length.should > 0
    end
  end

  context '#idletime' do

    subject{ described_class.new(idletime: 42) }

    it 'returns the thread idletime' do
      subject.idletime.should eq 42
    end
  end

  context 'garbage collection' do

    subject{ described_class.new(idletime: 1, max_threads: 5, gc_interval: 0) }

    it 'removes from pool any thread that has been idle too long' do
      3.times { subject << proc{ sleep(0.1) } }
      sleep(0.1)
      subject.length.should eq 3
      sleep(2)
      subject << proc{ nil }
      sleep(0.1)
      subject.length.should < 3
    end

    it 'removes from pool any dead thread' do
      3.times { subject << proc{ sleep(0.1); raise Exception } }
      sleep(0.1)
      subject.length.should eq 3
      sleep(2)
      subject << proc{ nil }
      sleep(0.1)
      subject.length.should < 3
    end
  end

  context 'worker creation and caching' do

    subject{ described_class.new(idletime: 1, max_threads: 5, gc_interval: 0) }

    it 'creates new workers when there are none available' do
      subject.length.should eq 0
      5.times{ sleep(0.1); subject << proc{ sleep(1) } }
      sleep(1)
      subject.length.should eq 5
    end

    it 'uses existing idle threads' do
      5.times{ subject << proc{ sleep(0.1) } }
      sleep(1)
      subject.length.should >= 5
      3.times{ subject << proc{ sleep(1) } }
      sleep(0.1)
      subject.length.should >= 5
    end

    it 'never creates more than :max_threads threads' do
      pool = described_class.new(max_threads: 5)
      100.times{ sleep(0.01); pool << proc{ sleep(1) } }
      sleep(0.1)
      pool.length.should eq 5
      pool.kill
    end
  end
end

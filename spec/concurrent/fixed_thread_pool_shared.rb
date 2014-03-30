require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :fixed_thread_pool do

  let!(:num_threads){ 5 }
  subject { described_class.new(num_threads) }

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#initialize' do

    it 'raises an exception when the pool length is less than one' do
      lambda {
        described_class.new(0)
      }.should raise_error(ArgumentError)
    end
  end

  context '#min_length' do

    it 'returns :num_threads on creation' do
      subject.min_length.should eq num_threads
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.min_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.min_length.should eq num_threads
    end
  end

  context '#max_length' do

    it 'returns :num_threads on creation' do
      subject.max_length.should eq num_threads
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.max_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.max_length.should eq num_threads
    end
  end

  context '#length' do

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.length.should eq num_threads
    end
  end

  context '#largest_length' do

    it 'returns zero on creation' do
      subject.largest_length.should eq 0
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.largest_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.largest_length.should eq num_threads
    end
  end

  context '#idletime' do

    it 'returns zero' do
      subject.idletime.should eq 0
    end
  end

  context '#kill' do

    it 'attempts to kill all in-progress tasks' do
      thread_count = [subject.length, 5].max
      @expected = false
      thread_count.times{ subject.post{ sleep(1) } }
      subject.post{ @expected = true }
      sleep(0.1)
      subject.kill
      sleep(0.1)
      @expected.should be_false
    end
  end

  context 'exception handling' do

    it 'restarts threads that experience exception' do
      count = subject.length
      count.times{ subject << proc{ raise StandardError } }
      sleep(1)
      subject.length.should eq count
    end
  end

  context 'worker creation and caching' do

    it 'creates new workers when there are none available' do
      pool = described_class.new(5)
      pool.current_length.should eq 0
      5.times{ pool << proc{ sleep(1) } }
      sleep(0.1)
      pool.current_length.should eq 5
      pool.kill
    end

    it 'never creates more than :num_threads threads' do
      pool = described_class.new(5)
      100.times{ pool << proc{ sleep(1) } }
      sleep(0.1)
      pool.current_length.should eq 5
      pool.kill
    end
  end
end

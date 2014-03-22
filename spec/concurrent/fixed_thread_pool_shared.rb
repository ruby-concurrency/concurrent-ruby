require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :fixed_thread_pool do

  subject { described_class.new(5) }

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

  context '#length' do

    let(:pool_length) { 3 }
    subject { described_class.new(pool_length) }

    it 'returns zero on start' do
      subject.shutdown
      subject.length.should eq 0
    end

    it 'returns the length of the pool when running' do
      pool_length.times do |i|
        subject.post{ sleep(1) }
        sleep(0.1)
        subject.length.should eq pool_length
      end
    end

    it 'returns zero while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.length.should eq 0
    end

    it 'returns zero once shut down' do
      subject.shutdown
      subject.length.should eq 0
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
end

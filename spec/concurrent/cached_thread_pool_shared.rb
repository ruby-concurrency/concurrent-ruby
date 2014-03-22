require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :cached_thread_pool do

  subject { described_class.new(max_threads: 5) }

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#length' do

    it 'returns a non-zero value when running' do
      subject.post{ sleep(1) }
      subject.length.should_not eq 0
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
end

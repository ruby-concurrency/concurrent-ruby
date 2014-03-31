require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :thread_pool_executor do

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#max_queue' do

    it 'is set to zero by default' do
      pending
    end

    it 'returns the set value on creation' do
      pending
    end

    it 'returns the set value when running' do
      pending
    end

    it 'returns the set value after stopping' do
      pending
    end
  end

  context '#queue_length' do

    it 'returns zero on creation' do
      pending
    end

    it 'returns zero when there are no enqueued tasks' do
      pending
    end

    it 'returns the size of the queue when tasks are enqueued' do
      pending
    end

    it 'returns zero when stopped' do
      pending
    end
  end

  context '#remaining_capacity' do

    it 'returns -1 when :max_queue is set to zero' do
      pending
    end

    it 'returns :max_size on creation' do
      pending
    end

    it 'returns :max_size when no tasks are enqueued' do
      pending
    end

    it 'returns the remaining capacity when tasks are enqueued' do
      pending
    end

    it 'returns :max_size when stopped' do
      pending
    end
  end

  context '#overload_policy' do
    pending
  end
end

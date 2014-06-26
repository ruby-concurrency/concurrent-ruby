require 'spec_helper'
require_relative 'executor_service_shared'

module Concurrent

  describe PerThreadExecutor do

    subject { PerThreadExecutor.new }

    it_should_behave_like :executor_service

    context '#post' do

      subject { PerThreadExecutor.new }

      it 'creates a new thread for a call without arguments' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(no_args()).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject.post{ nil }
      end

      it 'executes a call without arguments' do
        latch = CountDownLatch.new(1)
        subject.post{ latch.count_down }
        expect(latch.wait(1)).to be_truthy
      end

      it 'creates a new thread for a call with arguments' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(1,2,3).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject.post(1,2,3){ nil }
      end

      it 'executes a call with one argument' do
        latch = CountDownLatch.new(3)
        subject.post(3){|count| count.times{ latch.count_down } }
        expect(latch.wait(1)).to be_truthy
      end

      it 'executes a call with multiple arguments' do
        latch = CountDownLatch.new(10)
        subject.post(1,2,3,4){|*count| count.reduce(:+).times{ latch.count_down } }
        expect(latch.wait(1)).to be_truthy
      end

      it 'aliases #<<' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(no_args()).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject << proc{ nil }
      end
    end

    context 'PerThreadExecutor.post' do

      subject { PerThreadExecutor }

      it 'creates a new thread for a call without arguments' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(no_args()).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject.post{ nil }
      end

      it 'executes a call without arguments' do
        latch = CountDownLatch.new(1)
        subject.post{ latch.count_down }
        expect(latch.wait(1)).to be_truthy
      end

      it 'creates a new thread for a call with arguments' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(1,2,3).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject.post(1,2,3){ nil }
      end

      it 'executes a call with one argument' do
        latch = CountDownLatch.new(3)
        subject.post(3){|count| count.times{ latch.count_down } }
        expect(latch.wait(1)).to be_truthy
      end

      it 'executes a call with multiple arguments' do
        latch = CountDownLatch.new(10)
        subject.post(1,2,3,4){|*count| count.reduce(:+).times{ latch.count_down } }
        expect(latch.wait(1)).to be_truthy
      end

      it 'aliases #<<' do
        thread = Thread.new{ nil }
        expect(Thread).to receive(:new).with(no_args()).and_return(thread)
        expect(Concurrent.configuration.global_task_pool).not_to receive(:post).with(any_args())
        subject << proc{ nil }
      end
    end
  end
end

require 'spec_helper'

module Concurrent

  describe Condition do

    let(:mutex) { Mutex.new }
    subject{ Condition.new }

    before(:each) do
      # rspec is not thread safe, without mutex initialization
      # we can experience race conditions
      mutex
    end

    context 'with no waiting threads' do
      describe '#signal' do
        it 'should return immediately' do
          subject.signal.should be_true
        end
      end

      describe '#broadcast' do
        it 'should return immediately' do
          subject.broadcast.should be_true
        end
      end
    end

    context 'with one waiting thread' do

      context 'signalled wake up' do

        describe '#wait without timeout' do

          it 'should block the thread' do
            t = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            sleep(0.1)
            t.status.should eq 'sleep'
            t.kill
          end

          it 'should return a woken up result when is woken up by #signal' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex) } }
            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.1)
            result.should be_woken_up
            result.should_not be_timed_out
            result.remaining_time.should be_nil
            t.status.should be_false
          end

          it 'should return a woken up result when is woken up by #broadcast' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex) } }
            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.1)
            result.should be_woken_up
            result.should_not be_timed_out
            result.remaining_time.should be_nil
            t.status.should be_false
          end
        end

      end

      context 'timeout' do

        describe '#wait' do

          it 'should block the thread' do
            t = Thread.new { mutex.synchronize { subject.wait(mutex, 1) } }
            sleep(0.1)
            t.status.should eq 'sleep'
            t.kill
          end

          it 'should return remaining time when is woken up by #signal' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 1) } }
            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.1)
            result.should be_woken_up
            result.should_not be_timed_out
            result.remaining_time.should be_within(0.05).of(0.87)
            t.status.should be_false
          end

          it 'should return remaining time when is woken up by #broadcast' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 1) } }
            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.1)
            result.should be_woken_up
            result.should_not be_timed_out
            result.remaining_time.should be_within(0.05).of(0.87)
            t.status.should be_false
          end

          it 'should return 0 or negative number if timed out' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 0.1) } }
            sleep(0.2)
            result.should_not be_woken_up
            result.should be_timed_out
            result.remaining_time.should be_less_than_or_equal_to(0)
            t.status.should be_false
          end
        end

      end
    end

    context 'with many waiting threads' do

      context 'signalled wake up' do

        describe '#wait' do

          it 'should block threads' do
            t1 = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            sleep(0.1)
            [t1, t2].each { |t| t.status.should eq 'sleep' }
            [t1, t2].each { |t| t.kill }
          end

        end

        describe '#signal' do
          it 'wakes up only one thread' do
            latch = CountDownLatch.new(2)

            t1 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }

            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.2)

            latch.count.should eq 1
            [t1, t2].each { |t| t.kill }
          end
        end

        describe '#broadcast' do
          it 'wakes up all threads' do
            latch = CountDownLatch.new(2)

            t1 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }

            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.2)

            latch.count.should eq 0
            [t1, t2].each { |t| t.kill }
          end
        end
      end

    end

  end
end

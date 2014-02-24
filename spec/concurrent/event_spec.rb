require 'spec_helper'

module Concurrent

  describe Event do

    subject{ Event.new }

    context '#initialize' do

      it 'sets the state to unset' do
        subject.should_not be_set
      end
    end

    context '#set?' do

      it 'returns true when the event has been set' do
        subject.set
        subject.should be_set
      end

      it 'returns false if the event is unset' do
        #subject.reset
        subject.should_not be_set
      end
    end

    context '#set' do

      it 'triggers the event' do
        #subject.reset
        @expected = false
        Thread.new{ subject.wait; @expected = true }
        sleep(0.1)
        subject.set
        sleep(0.1)
        @expected.should be_true
      end

      it 'sets the state to set' do
        subject.set
        subject.should be_set
      end
    end

    context '#reset' do

      it 'does not change the state of an unset event' do
        subject.reset
        subject.should_not be_set
      end
 
      it 'does not trigger an unset event' do
        @expected = false
        Thread.new{ subject.wait; @expected = true }
        sleep(0.1)
        subject.reset
        sleep(0.1)
        @expected.should be_false
      end

      it 'does not interrupt waiting threads when event is unset' do
        @expected = false
        Thread.new{ subject.wait; @expected = true }
        sleep(0.1)
        subject.reset
        sleep(0.1)
        subject.set
        sleep(0.1)
        @expected.should be_true
      end

      it 'returns true when called on an unset event' do
        subject.reset.should be_true
      end

      it 'sets the state of a set event to unset' do
        subject.set
        subject.should be_set
        subject.reset
        subject.should_not be_set
      end

      it 'returns true when called on a set event' do
        subject.set
        subject.should be_set
        subject.reset.should be_true
      end
    end

    context '#wait' do

      it 'returns immediately when the event has been set' do
        subject.reset
        @expected = false
        subject.set
        Thread.new{ subject.wait(1000); @expected = true}
        sleep(1)
        @expected.should be_true
      end

      it 'returns true once the event is set' do
        subject.set
        subject.wait.should be_true
      end

      it 'blocks indefinitely when the timer is nil' do
        subject.reset
        @expected = false
        Thread.new{ subject.wait; @expected = true}
        subject.set
        sleep(1)
        @expected.should be_true
      end

      it 'stops waiting when the timer expires' do
        subject.reset
        @expected = false
        Thread.new{ subject.wait(0.5); @expected = true}
        sleep(1)
        @expected.should be_true
      end

      it 'returns false when the timer expires' do
        subject.reset
        subject.wait(1).should be_false
      end

      it 'triggers multiple waiting threads' do
        latch = CountDownLatch.new(5)
        subject.reset
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        subject.set
        latch.wait(0.2).should be_true
      end

      it 'behaves appropriately if wait begins while #set is processing' do
        subject.reset
        latch = CountDownLatch.new(5)
        5.times{ Thread.new{ subject.wait(5) } }
        subject.set
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        latch.wait(0.2).should be_true
      end
    end

    context 'spurious wake ups' do

      before(:each) do
        def subject.wake_up
          @mutex.synchronize do
            @condition.signal
            @condition.broadcast
          end
        end
      end

      it 'should resist to spurious wake ups without timeout' do
        @expected = false
        Thread.new { subject.wait; @expected = true }

        sleep(0.1)
        subject.wake_up

        sleep(0.1)
        @expected.should be_false
      end

      it 'should resist to spurious wake ups with timeout' do
        @expected = false
        Thread.new { subject.wait(0.5); @expected = true }

        sleep(0.1)
        subject.wake_up

        sleep(0.1)
        @expected.should be_false

        sleep(0.4)
        @expected.should be_true
      end
    end
  end
end

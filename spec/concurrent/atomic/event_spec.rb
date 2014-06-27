require 'spec_helper'

module Concurrent

  describe Event do

    subject{ Event.new }

    context '#initialize' do

      it 'sets the state to unset' do
        expect(subject).not_to be_set
      end
    end

    context '#set?' do

      it 'returns true when the event has been set' do
        subject.set
        expect(subject).to be_set
      end

      it 'returns false if the event is unset' do
        expect(subject).not_to be_set
      end
    end

    context '#set' do

      it 'triggers the event' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        sleep(0.1)
        subject.set
        expect(latch.wait(1)).to be_truthy
      end

      it 'sets the state to set' do
        subject.set
        expect(subject).to be_set
      end
    end

    context '#try?' do

      it 'triggers the event if not already set' do
        subject.try?
        expect(subject).to be_set
      end

      it 'returns true if not previously set' do
        expect(subject.try?).to be_truthy
      end

      it 'returns false if previously set' do
        subject.set
        expect(subject.try?).to be_falsey
      end
    end

    context '#reset' do

      it 'does not change the state of an unset event' do
        subject.reset
        expect(subject).not_to be_set
      end

      it 'does not trigger an unset event' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        subject.reset
        expect(latch.wait(0.1)).to be_falsey
      end

      it 'does not interrupt waiting threads when event is unset' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        subject.reset
        expect(latch.wait(0.1)).to be_falsey
        subject.set
        expect(latch.wait(0.1)).to be_truthy
      end

      it 'returns true when called on an unset event' do
        expect(subject.reset).to be_truthy
      end

      it 'sets the state of a set event to unset' do
        subject.set
        expect(subject).to be_set
        subject.reset
        expect(subject).not_to be_set
      end

      it 'returns true when called on a set event' do
        subject.set
        expect(subject).to be_set
        expect(subject.reset).to be_truthy
      end
    end

    #context '#pulse' do

      #it 'triggers an unset event' do
        #subject.reset
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ puts "Boom!"; latch.count_down } }
        #subject.pulse
        #latch.wait(0.1).should be_true
      #end

      #it 'does nothing with a set event' do
        #subject.set
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ latch.count_down } }
        #subject.pulse
        #latch.wait(0.1).should be_true
      #end

      #it 'leaves the event in the unset state' do
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ latch.count_down } }
        #subject.pulse
        #latch.wait(0.1)
        #subject.should_not be_set
      #end
    #end

    context '#wait' do

      it 'returns immediately when the event has been set' do
        subject.reset
        latch = CountDownLatch.new(1)
        subject.set
        Thread.new{ subject.wait(1000); latch.count_down }
        expect(latch.wait(0.1)).to be_truthy
      end

      it 'returns true once the event is set' do
        subject.set
        expect(subject.wait).to be_truthy
      end

      it 'blocks indefinitely when the timer is nil' do
        subject.reset
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        expect(latch.wait(0.1)).to be_falsey
        subject.set
        expect(latch.wait(0.1)).to be_truthy
      end

      it 'stops waiting when the timer expires' do
        subject.reset
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait(0.2); latch.count_down }
        expect(latch.wait(0.1)).to be_falsey
        expect(latch.wait).to be_truthy
      end

      it 'returns false when the timer expires' do
        subject.reset
        expect(subject.wait(1)).to be_falsey
      end

      it 'triggers multiple waiting threads' do
        latch = CountDownLatch.new(5)
        subject.reset
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        subject.set
        expect(latch.wait(0.2)).to be_truthy
      end

      it 'behaves appropriately if wait begins while #set is processing' do
        subject.reset
        latch = CountDownLatch.new(5)
        5.times{ Thread.new{ subject.wait(5) } }
        subject.set
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        expect(latch.wait(0.2)).to be_truthy
      end
    end

    context 'spurious wake ups' do

      before(:each) do
        def subject.simulate_spurious_wake_up
          @mutex.synchronize do
            @condition.signal
            @condition.broadcast
          end
        end
      end

      it 'should resist to spurious wake ups without timeout' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }

        sleep(0.1)
        subject.simulate_spurious_wake_up

        expect(latch.wait(0.1)).to be_falsey
      end

      it 'should resist to spurious wake ups with timeout' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait(0.3); latch.count_down }

        sleep(0.1)
        subject.simulate_spurious_wake_up

        expect(latch.wait(0.1)).to be_falsey
        expect(latch.wait(1)).to be_truthy
      end
    end
  end
end

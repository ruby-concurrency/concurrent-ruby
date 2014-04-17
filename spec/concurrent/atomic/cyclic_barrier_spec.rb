require 'spec_helper'

module Concurrent

  describe CyclicBarrier do

    let(:parties) { 3 }
    let!(:barrier) { described_class.new(3) }

    context '#initialize' do

      it 'raises an exception if the initial count is less than 1' do
        expect {
          described_class.new(0)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception if the initial count is not an integer' do
        expect {
          described_class.new('foo')
        }.to raise_error(ArgumentError)
      end
    end

    describe '#parties' do

      it 'should be the value passed to the constructor' do
        barrier.parties.should eq 3
      end

    end

    describe '#number_waiting' do
      context 'without any waiting thread' do
        it 'should be equal to zero' do
          barrier.number_waiting.should eq 0
        end
      end

      context 'with waiting threads' do
        it 'should be equal to the waiting threads count' do
          Thread.new { barrier.wait }
          Thread.new { barrier.wait }

          sleep(0.1)

          barrier.number_waiting.should eq 2
        end
      end
    end

    describe '#broken?' do
      it 'should not be broken when created' do
        barrier.broken?.should eq false
      end

      it 'should not be broken when reset is called without waiting thread' do
        barrier.reset
        barrier.broken?.should eq false
      end
    end

    describe 'reset' do
      it 'should release all waiting threads' do
        latch = CountDownLatch.new(1)

        Thread.new { barrier.wait; latch.count_down }
        sleep(0.1)
        barrier.reset
        latch.wait(0.1).should be_true

        barrier.should_not be_broken
        barrier.number_waiting.should eq 0
      end
    end

    describe '#wait' do
      context 'without timeout' do
        it 'should block the thread' do
          t = Thread.new { barrier.wait }
          sleep(0.1)

          t.status.should eq 'sleep'
        end

        it 'should release all threads when their number matches the desired one' do
          latch = CountDownLatch.new(parties)

          parties.times { Thread.new { barrier.wait; latch.count_down } }
          latch.wait(0.1).should be_true
          barrier.number_waiting.should eq 0
          barrier.should_not be_broken
        end

        it 'returns true when released' do
          latch = CountDownLatch.new(parties)

          parties.times { Thread.new { latch.count_down if barrier.wait == true } }
          latch.wait(0.1).should be_true
        end

        it 'executes the block once' do
          counter = AtomicFixnum.new
          barrier = described_class.new(parties) { counter.increment }

          latch = CountDownLatch.new(parties)

          parties.times { Thread.new { latch.count_down if barrier.wait == true } }
          latch.wait(0.1).should be_true

          counter.value.should eq 1
        end

        it 'can be reused' do
          first_latch = CountDownLatch.new(parties)
          parties.times { Thread.new { barrier.wait; first_latch.count_down } }
          first_latch.wait(0.1).should be_true

          latch = CountDownLatch.new(parties)
          parties.times { Thread.new { barrier.wait; latch.count_down } }
          latch.wait(0.1).should be_true
        end

        it 'return false if barrier has been reset' do
          latch = CountDownLatch.new(1)

          Thread.new { latch.count_down if barrier.wait == false }
          sleep(0.1)
          barrier.reset
          latch.wait(0.1).should be_true
        end
      end

      context 'with timeout' do
        context 'timeout not expiring' do
          it 'should block the thread' do
            t = Thread.new { barrier.wait(1) }
            sleep(0.1)

            t.status.should eq 'sleep'
          end

          it 'should release all threads when their number matches the desired one' do
            latch = CountDownLatch.new(parties)

            parties.times { Thread.new { barrier.wait(1); latch.count_down } }
            latch.wait(0.2).should be_true
            barrier.number_waiting.should eq 0
          end

          it 'returns true when released' do
            latch = CountDownLatch.new(parties)

            parties.times { Thread.new { latch.count_down if barrier.wait(1) == true } }
            latch.wait(0.1).should be_true
          end
        end

        context 'timeout expiring' do

          it 'returns false' do
            latch = CountDownLatch.new(1)

            Thread.new { latch.count_down if barrier.wait(0.1) == false }
            latch.wait(0.2).should be_true
          end

          it 'breaks the barrier and release all other threads' do
            latch = CountDownLatch.new(2)

            Thread.new { barrier.wait(0.1); latch.count_down }
            Thread.new { barrier.wait; latch.count_down }

            latch.wait(0.2).should be_true
            barrier.should be_broken
          end

          it 'does not execute the block on timeout' do
            counter = AtomicFixnum.new
            barrier = described_class.new(parties) { counter.increment }

            barrier.wait(0.1)

            counter.value.should eq 0
          end
        end
      end

      context '#broken barrier' do
        it 'should not accept new threads' do
          Thread.new { barrier.wait(0.1) }
          sleep(0.2)

          barrier.should be_broken

          barrier.wait.should be_false
        end

        it 'can be reset' do
          Thread.new { barrier.wait(0.1) }
          sleep(0.2)

          barrier.should be_broken

          barrier.reset

          barrier.should_not be_broken
        end
      end
    end

    context 'spurious wake ups' do

      before(:each) do
        def barrier.simulate_spurious_wake_up
          @mutex.synchronize do
            @condition.signal
            @condition.broadcast
          end
        end
      end

      it 'should resist to spurious wake ups without timeout' do
        @expected = false
        Thread.new { barrier.wait; @expected = true }

        sleep(0.1)
        barrier.simulate_spurious_wake_up

        sleep(0.1)
        @expected.should be_false
      end

      it 'should resist to spurious wake ups with timeout' do
        @expected = false
        Thread.new { barrier.wait(0.5); @expected = true }

        sleep(0.1)
        barrier.simulate_spurious_wake_up

        sleep(0.1)
        @expected.should be_false

      end
    end
  end

end

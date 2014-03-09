require 'spec_helper'

module Concurrent

  describe CountDownLatch do

    let(:latch) { CountDownLatch.new(3) }
    let(:zero_count_latch) { CountDownLatch.new(0) }

    context '#initialize' do

      it 'raises an exception if the initial count is less than zero' do
        expect {
          CountDownLatch.new(-1)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception if the initial count is not an integer' do
        expect {
          CountDownLatch.new('foo')
        }.to raise_error(ArgumentError)
      end
    end

    describe '#count' do

      it 'should be the value passed to the constructor' do
        latch.count.should eq 3
      end

      it 'should be decreased after every count down' do
        latch.count_down
        latch.count.should eq 2
      end

      it 'should not go below zero' do
        5.times { latch.count_down }
        latch.count.should eq 0
      end
    end

    describe '#wait' do

      context 'count set to zero' do
        it 'should return true immediately' do
          result = zero_count_latch.wait
          result.should be_true
        end

        it 'should return true immediately with timeout' do
          result = zero_count_latch.wait(5)
          result.should be_true
        end
      end

      context 'non zero count' do

        it 'should block thread until counter is set to zero' do
          3.times do
            Thread.new { sleep(0.1); latch.count_down }
          end

          result = latch.wait
          result.should be_true
          latch.count.should eq 0
        end

        it 'should block until counter is set to zero with timeout' do
          3.times do
            Thread.new { sleep(0.1); latch.count_down }
          end

          result = latch.wait(1)
          result.should be_true
          latch.count.should eq 0

        end

        it 'should block until timeout and return false when counter is not set to zero' do
          result = latch.wait(0.1)
          result.should be_false
          latch.count.should eq 3
        end
      end
    end

    context 'spurious wake ups' do

      before(:each) do
        def latch.simulate_spurious_wake_up
          @mutex.synchronize do
            @condition.signal
            @condition.broadcast
          end
        end
      end

      it 'should resist to spurious wake ups without timeout' do
        @expected = false
        Thread.new { latch.wait; @expected = true }

        sleep(0.1)
        latch.simulate_spurious_wake_up

        sleep(0.1)
        @expected.should be_false
      end

      it 'should resist to spurious wake ups with timeout' do
        @expected = false
        Thread.new { latch.wait(0.5); @expected = true }

        sleep(0.1)
        latch.simulate_spurious_wake_up

        sleep(0.1)
        @expected.should be_false

        sleep(0.4)
        @expected.should be_true
      end
    end

  end
end

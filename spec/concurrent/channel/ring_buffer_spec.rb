require 'spec_helper'

module Concurrent

  describe RingBuffer do

    let(:capacity) { 3 }
    let(:buffer) { RingBuffer.new( capacity ) }

    describe '#capacity' do
      it 'returns the value passed in constructor' do
        buffer.capacity.should eq capacity
      end
    end

    describe '#count' do
      it 'is zero when created' do
        buffer.count.should eq 0
      end

      it 'increases when an element is added' do
        buffer.put 5
        buffer.count.should eq 1

        buffer.put 1
        buffer.count.should eq 2
      end

      it 'decreases when an element is removed' do
        buffer.put 10

        buffer.take

        buffer.count.should eq 0
      end
    end

    describe '#put' do
      it 'block when buffer is full' do
        capacity.times { buffer.put 27 }

        t = Thread.new { buffer.put 32 }

        sleep(0.1)

        t.status.should eq 'sleep'
      end

      it 'continues when an element is removed' do
        latch = CountDownLatch.new(1)

        Thread.new { (capacity + 1).times { buffer.put 'hi' }; latch.count_down }
        Thread.new { sleep(0.1); buffer.take }

        latch.wait(0.2).should be_true
      end
    end

    describe '#take' do
      it 'blocks when buffer is empty' do
        t = Thread.new { buffer.take }

        sleep(0.1)

        t.status.should eq 'sleep'
      end

      it 'continues when an element is added' do
        latch = CountDownLatch.new(1)

        Thread.new { buffer.take; latch.count_down }
        Thread.new { sleep(0.1); buffer.put 3 }

        latch.wait(0.2).should be_true
      end

      it 'returns the first added value' do
        buffer.put 'hi'
        buffer.put 'foo'
        buffer.put 'bar'

        buffer.take.should eq 'hi'
        buffer.take.should eq 'foo'
        buffer.take.should eq 'bar'
      end
    end

    context 'circular condition' do
      it 'can filled many times' do
        capacity.times { buffer.put 3 }
        capacity.times { buffer.take }

        buffer.put 'hi'

        buffer.take.should eq 'hi'
        buffer.capacity.should eq capacity
      end
    end

  end
end

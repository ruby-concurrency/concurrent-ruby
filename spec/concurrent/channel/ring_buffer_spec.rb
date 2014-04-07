require 'spec_helper'

module Concurrent

  describe RingBuffer do

    let(:capacity) { 3 }
    let(:buffer) { RingBuffer.new(capacity) }

    def fill_buffer
      capacity.times { buffer.offer 3 }
    end

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
        buffer.offer 5
        buffer.count.should eq 1

        buffer.offer 1
        buffer.count.should eq 2
      end

      it 'decreases when an element is removed' do
        buffer.offer 10
        buffer.poll

        buffer.count.should eq 0
      end
    end

    describe '#empty?' do
      it 'is true when count is zero' do
        buffer.empty?.should be_true
      end

      it 'is false when count is not zero' do
        buffer.offer 82
        buffer.empty?.should be_false
      end
    end

    describe '#full?' do
      it 'is true when count is capacity' do
        fill_buffer
        buffer.full?.should be_true
      end

      it 'is false when count is not capacity' do
        buffer.full?.should be_false
      end
    end

    describe '#offer' do
      it 'returns false when buffer is full' do
        fill_buffer
        buffer.offer(3).should be_false
      end

      it 'returns true when the buffer is not full' do
        buffer.offer(5).should be_true
      end

    end

    describe '#poll' do
      it 'returns the first added value' do
        buffer.offer 'hi'
        buffer.offer 'foo'
        buffer.offer 'bar'

        buffer.poll.should eq 'hi'
        buffer.poll.should eq 'foo'
        buffer.poll.should eq 'bar'
      end

      it 'returns nil when buffer is empty' do
        buffer.poll.should be_nil
      end
    end

    describe '#peek' do
      context 'buffer empty' do
        it 'returns nil when buffer is empty' do
          buffer.peek.should be_nil
        end
      end

      context 'not empty' do

        before(:each) { buffer.offer 'element' }

        it 'returns the first value' do
          buffer.peek.should eq 'element'
        end

        it 'does not change buffer' do
          buffer.peek
          buffer.count.should eq 1
        end
      end
    end

    context 'circular condition' do
      it 'can filled many times' do
        fill_buffer
        capacity.times { buffer.poll }

        buffer.offer 'hi'

        buffer.poll.should eq 'hi'
        buffer.capacity.should eq capacity
      end
    end

  end
end

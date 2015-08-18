require 'thread'
require_relative 'collection/priority_queue_shared'

shared_examples :blocking_queue do

  context '#clear' do

    it 'removes all items from a populated queue' do
      10.times{|i| subject.push i}
      subject.clear
      expect(subject).to be_empty
    end

    it 'has no effect on an empty queue' do
      subject.clear
      expect(subject).to be_empty
    end

    it 'returns self' do
      expect(subject.clear).to eq subject

      subject.push(1)
      expect(subject.clear).to eq subject
    end
  end

  context '#empty?' do

    it 'returns true for an empty queue' do
      expect(subject).to be_empty
    end

    it 'returns false for a populated queue' do
      10.times{|i| subject.push i}
      expect(subject).not_to be_empty
    end
  end

  context '#length' do

    it 'returns the length of a populated queue' do
      10.times{|i| subject.push i}
      expect(subject.length).to eq 10
    end

    it 'returns zero when the queue is empty' do
      expect(subject.length).to eq 0
    end

    it 'is aliased as #size' do
      10.times{|i| subject.push i}
      expect(subject.size).to eq 10
    end
  end

  context '#num_waiting' do

    it 'returns zero when no threads are waiting' do
      expect(subject.num_waiting).to eq 0
    end

    it 'returns the number of waiting threads' do
      waiters = 5
      latch = Concurrent::CountDownLatch.new(waiters)
      subject.clear

      threads = waiters.times.collect do
        Thread.new { latch.count_down; subject.pop(false) }
      end

      latch.wait(1)
      threads.each{|t| t.join(0.1) }
      actual = subject.num_waiting

      waiters.times{|i| subject.push(i) }
      threads.each{|t| t.kill }

      expect(actual).to eq waiters
    end
  end

  context '#pop' do

    it 'returns the item at the head of the queue' do
      10.times{|i| subject.push i}
      expect(subject.pop).to eq 0
    end

    it 'removes the item from the queue' do
      10.times{|i| subject.push i}
      subject.pop
      expect(subject.length).to eq 9
      expect(subject.pop).not_to eq 0
    end

    it 'is aliased as #deq' do
      10.times{|i| subject.push i}
      expect(subject.deq).to eq 0
    end

    it 'is aliased as #shift' do
      10.times{|i| subject.push i}
      expect(subject.shift).to eq 0
    end

    context 'when non_block is true' do

      it 'raises an exception when the queue is empty' do
        expect {
          subject.pop(true)
        }.to raise_error(ThreadError)
      end
    end

    context 'when non_block is false' do

      it 'blocks and waits for the next item' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.clear

        t = Thread.new do
          item = subject.pop(false)
          latch.count_down if item == 42
        end

        t.join(0.2)

        subject.push(42)
        expect(latch.wait(1)).to be true

        t.kill
      end
    end
  end

  context '#push' do

    it 'adds the item to the queue' do
      subject.push(1)
      expect(subject.pop).to eq 1
    end

    it 'sorts the new item in insertion order' do
      3.times{|i| subject.push i}
      expect(subject.pop).to eq 0
      expect(subject.pop).to eq 1
      expect(subject.pop).to eq 2
    end

    specify { expect(subject.push(10)).to be_truthy }

    it 'is aliased as <<' do
      subject << 1
      expect(subject.pop).to eq 1
    end

    it 'is aliased as enq' do
      subject.enq(1)
      expect(subject.pop).to eq 1
    end
  end
end

shared_examples :polling_blocking_queue do

  context '#poll' do

    it 'returns nil if timeout is nil and the queue is empty' do
      subject.clear
      expect(subject.poll(nil)).to be nil
    end

    it 'immediately returns the head when there are items' do
      subject.push(42)
      expect(subject.poll(1)).to eq 42
      expect(subject).to be_empty
    end

    it 'when given a timeout it blocks and waits for a #push to return the head' do
      start_latch = Concurrent::CountDownLatch.new(1)
      end_latch = Concurrent::CountDownLatch.new(1)
      actual = Concurrent::AtomicReference.new(0)
      subject.clear

      t = Thread.new do
        start_latch.count_down
        actual.value = subject.poll(1)
        end_latch.count_down
      end

      start_latch.wait(1)
      t.join(0.2)
      subject.push(42)
      end_latch.wait(1)
      t.kill

      expect(actual.value).to eq 42
    end

    it 'waits on an empty queue until timeout' do
      start_time = Concurrent.monotonic_time
      actual = subject.poll(1)
      expect(actual).to be nil
      expect(Concurrent.monotonic_time - start_time).to be > 1.0
    end
  end
end

# # reference implementation
# describe Queue do
#   it_behaves_like :blocking_queue
# end

module Concurrent

  describe MutexPriorityBlockingQueue do

    subject { described_class.new(order: :min) }

    it_behaves_like :priority_queue
    it_behaves_like :blocking_queue
    it_behaves_like :polling_blocking_queue
  end

  if Concurrent.on_jruby?

    describe JavaPriorityBlockingQueue do

      subject { described_class.new(order: :min) }

      it_behaves_like :priority_queue
      it_behaves_like :blocking_queue
      it_behaves_like :polling_blocking_queue
    end
  end

  describe PriorityBlockingQueue do
    if Concurrent.on_jruby?
      it 'inherits from JavaPriorityBlockingQueue' do
        expect(PriorityBlockingQueue.ancestors).to include(JavaPriorityBlockingQueue)
      end
    else
      it 'inherits from MutexPriorityBlockingQueue' do
        expect(PriorityBlockingQueue.ancestors).to include(MutexPriorityBlockingQueue)
      end
    end
  end
end

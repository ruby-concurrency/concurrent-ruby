require_relative 'base_shared'

shared_examples :channel_buffered_buffer do

  it_behaves_like :channel_buffer

  context 'initialization' do

    it 'raises an exception if size <= 0' do
      expect {
        described_class.new(0)
      }.to raise_error(ArgumentError)
    end
  end

  context '#size' do

    it 'returns the maximum size of the buffer' do
      subject = described_class.new(10)
      expect(subject.size).to eq 10
    end
  end

  context '#empty?' do

    it 'returns true when empty' do
      subject = described_class.new(10)
      expect(subject).to be_empty
    end
  end

  context '#put' do

    it 'enqueues the item when size > 0, not full, and not closed' do
      subject.put(:foo)
      expect(subject).to_not be_empty
    end

    it 'returns true when the item is put' do
      expect(subject.put(:foo)).to be true
    end
  end

  context '#offer' do

    it 'enqueues the item immediately when not full and not closed' do
      subject.offer(:foo)
      expect(subject.take).to eq :foo
    end
  end

  context '#take' do

    it 'returns the first item when not empty' do
      subject.put(:foo)
      expect(subject.take).to eq :foo
    end

    it 'blocks until not empty' do
      subject # initialize on this thread
      bucket = Concurrent::AtomicReference.new(nil)
      t = Thread.new do
        bucket.value = subject.take
      end
      t.join(0.1)

      before = bucket.value
      subject.put(42)
      t.join(0.1)
      after = bucket.value

      expect(before).to be nil
      expect(after).to eq 42
      expect(t.status).to be false
    end

    it 'returns NO_VALUE when closed and empty' do
      subject.close
      expect(subject.take).to eq Concurrent::Edge::Channel::Buffer::NO_VALUE
    end
  end

  context '#next' do

    it 'blocks until not empty' do
      subject # initialize on this thread
      bucket = Concurrent::AtomicReference.new([])
      t = Thread.new do
        bucket.value = subject.next
      end
      t.join(0.1)

      before = bucket.value
      subject.put(42)
      t.join(0.1)
      after = bucket.value

      expect(before).to eq []
      expect(after.first).to eq 42
      expect(after.last).to be true
      expect(t.status).to be false
    end

    it 'returns <item>, true when there is only one item and not closed' do
      subject.offer(42)

      item, more = subject.next
      expect(item).to eq 42
      expect(more).to be true
    end

    it 'returns <item>, true when there are multiple items' do
      subject.offer(:foo)
      subject.offer(:bar)
      subject.offer(:baz)

      item1, more1 = subject.next
      item2, more2 = subject.next
      item3, more3 = subject.next

      expect(item1).to eq :foo
      expect(more1).to be true

      expect(item2).to eq :bar
      expect(more2).to be true

      expect(item3).to eq :baz
      expect(more3).to be true
    end

    it 'returns <item> false when closed and last item' do
      subject.offer(:foo)
      subject.offer(:bar)
      subject.offer(:baz)
      subject.close

      _, more1 = subject.next
      _, more2 = subject.next
      _, more3 = subject.next

      expect(more1).to be true
      expect(more2).to be true
      expect(more3).to be false
    end
  end
end

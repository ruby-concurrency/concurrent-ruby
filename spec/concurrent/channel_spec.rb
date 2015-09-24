module Concurrent

  describe Channel do

    context 'initialization' do

      it 'raises an exception when the :buffer is invalid' do
        expect {
          Channel.new(buffer: :bogus)
        }.to raise_error(ArgumentError)
      end

      it 'is :unbuffered when neither :buffer nore :size is given' do
        expect(Channel::Buffer::Unbuffered).to receive(:new).with(no_args).and_call_original
        Channel.new
      end

      it 'is :unbuffered when :unbuffered is given' do
        expect(Channel::Buffer::Unbuffered).to receive(:new).with(no_args).and_call_original
        Channel.new(buffer: :unbuffered)
      end

      it 'is :unbuffered when :buffered and size: 0' do
        expect(Channel::Buffer::Unbuffered).to receive(:new).with(no_args).and_call_original
        Channel.new(buffer: :buffered, size: 0)
      end

      it 'raises an exception when both :unbuffered and :size are given' do
        expect {
          Channel.new(buffer: :unbuffered, size: 0)
        }.to raise_error(ArgumentError)
      end

      it 'is :buffered when :size > 0 and no :buffer given' do
        expect(Channel::Buffer::Buffered).to receive(:new).with(5).and_call_original
        Channel.new(size: 5)
      end

      it 'is :buffered when :buffered given' do
        expect(Channel::Buffer::Buffered).to receive(:new).with(5).and_call_original
        Channel.new(buffer: :buffered, size: 5)
      end

      it 'raises an exception when :buffered given without :size' do
        expect {
          Channel.new(buffer: :buffered)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when :buffered and :size < 0' do
        expect {
          Channel.new(buffer: :buffered, size: -1)
        }.to raise_error(ArgumentError)
      end

      it 'is :dropping when :dropping and :size > 0' do
        expect(Channel::Buffer::Dropping).to receive(:new).with(5).and_call_original
        Channel.new(buffer: :dropping, size: 5)
      end

      it 'raises an exception when :dropping given without :size' do
        expect {
          Channel.new(buffer: :dropping)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when :dropping and :size < 1' do
        expect {
          Channel.new(buffer: :dropping, size: 0)
        }.to raise_error(ArgumentError)
      end

      it 'is :sliding when :sliding and :size > 0' do
        expect(Channel::Buffer::Sliding).to receive(:new).with(5).and_call_original
        Channel.new(buffer: :sliding, size: 5)
      end

      it 'raises an exception when :sliding given without :size' do
        expect {
          Channel.new(buffer: :sliding)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when :sliding and :size < 1' do
        expect {
          Channel.new(buffer: :sliding, size: 0)
        }.to raise_error(ArgumentError)
      end
    end

    context '#put' do

      it 'enqueues the item when not full and not closed' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.put(:foo)
        internal_buffer = subject.instance_variable_get(:@buffer)
        expect(internal_buffer).to_not be_empty
      end

      it 'returns true on success' do
        subject = Channel.new(buffer: :buffered, size: 2)
        expect(subject.put(:foo)).to be true
      end

      it 'returns false when closed' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        expect(subject.put(:foo)).to be false
      end
    end

    context 'put!' do

      it 'raises an exception on failure' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        expect {
          subject.put!(:foo)
        }.to raise_error(Channel::Error)
      end
    end

    context 'put?' do

      it 'returns a just Maybe on success' do
        subject = Channel.new(buffer: :buffered, size: 2)
        result = subject.put?(:foo)
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_just
      end

      it 'returns a nothing Maybe on failure' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        result = subject.put?(:foo)
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_nothing
      end
    end

    context '#offer' do

      it 'enqueues the item when not full and not closed' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.offer(:foo)
        internal_buffer = subject.instance_variable_get(:@buffer)
        expect(internal_buffer).to_not be_empty
      end

      it 'returns true on success' do
        subject = Channel.new(buffer: :buffered, size: 2)
        expect(subject.offer(:foo)).to be true
      end

      it 'returns false when closed' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        expect(subject.offer(:foo)).to be false
      end
    end

    context 'offer!' do

      it 'raises an exception on failure' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        expect {
          subject.offer!(:foo)
        }.to raise_error(Channel::Error)
      end
    end

    context 'offer?' do

      it 'returns a just Maybe on success' do
        subject = Channel.new(buffer: :buffered, size: 2)
        result = subject.offer?(:foo)
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_just
      end

      it 'returns a nothing Maybe on failure' do
        subject = Channel.new(buffer: :buffered, size: 2)
        subject.close
        result = subject.offer?(:foo)
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_nothing
      end
    end

    context '#take' do

      subject { Channel.new(buffer: :buffered, size: 2) }

      it 'takes the next item when not empty' do
        subject.put(:foo)
        expect(subject.take).to eq :foo
      end

      it 'returns nil when empty and closed' do
        subject.close
        expect(subject.take).to be nil
      end
    end

    context '#take!' do

      subject { Channel.new(buffer: :buffered, size: 2) }

      it 'raises an exception on failure' do
        subject.close
        expect {
          subject.take!
        }.to raise_error(Channel::Error)
      end
    end

    context '#take?' do

      subject { Channel.new(buffer: :buffered, size: 2) }

      it 'returns a just Maybe on success' do
        subject.put(:foo)
        result = subject.take?
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_just
        expect(result.value).to eq :foo
      end

      it 'returns a nothing Maybe on failure' do
        subject.close
        result = subject.take?
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_nothing
      end
    end

    context '#next' do

      subject { Channel.new(buffer: :buffered, size: 3) }

      it 'returns <item>, true when there is one item' do
        subject.put(:foo)
        item, more = subject.next
        expect(item).to eq :foo
        expect(more).to be true
      end

      it 'returns <item>, true when there are multiple items' do
        subject.put(:foo)
        subject.put(:bar)
        item, more = subject.next
        subject.poll # clear the buffer

        expect(item).to eq :foo
        expect(more).to be true
      end

      it 'returns nil, false when empty and closed' do
        subject.close
        item, more = subject.next
        expect(item).to be nil
        expect(more).to be false
      end

      it 'returns <item>, false when closed and last item' do
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

    context '#next?' do

      subject { Channel.new(buffer: :buffered, size: 2) }

      it 'returns a just Maybe and true when there is one item' do
        subject.put(:foo)
        item, more = subject.next?
        expect(item).to be_a Concurrent::Maybe
        expect(item).to be_just
        expect(item.value).to eq :foo
        expect(more).to be true
      end

      it 'returns a just Maybe, true when there are multiple items' do
        subject.put(:foo)
        subject.put(:bar)
        item, more = subject.next?
        subject.poll # clear the buffer

        expect(item).to be_a Concurrent::Maybe
        expect(item).to be_just
        expect(item.value).to eq :foo
        expect(more).to be true
      end

      it 'returns a nothing Maybe and false on failure' do
        subject.close
        item, more = subject.next?
        expect(item).to be_a Concurrent::Maybe
        expect(item).to be_nothing
        expect(more).to be false
      end
    end

    context '#poll' do

      it 'returns the next item immediately if available' do
        subject # initialize on this thread
        t = Thread.new do
          subject.put(42)
        end
        t.join(0.1)

        expect(subject.poll).to eq 42
      end

      it 'returns nil immediately if no item is available' do
        expect(subject.poll).to be nil
      end

      it 'returns nil when closed' do
        subject.close
        expect(subject.poll).to be nil
      end
    end

    context '#poll!' do

      it 'raises an exception immediately if no item is available' do
        expect {
          subject.poll!
        }.to raise_error(Channel::Error)
      end

      it 'raises an exception when closed' do
        subject.close
        expect {
          subject.poll!
        }.to raise_error(Channel::Error)
      end
    end

    context '#poll?' do

      it 'returns a just Maybe immediately if available' do
        subject # initialize on this thread
        t = Thread.new do
          subject.put(42)
        end
        t.join(0.1)

        result = subject.poll?
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_just
        expect(result.value).to eq 42
      end

      it 'returns a nothing Maybe immediately if no item is available' do
        result = subject.poll?
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_nothing
      end

      it 'returns a nothing Maybe when closed' do
        subject.close
        result = subject.poll?
        expect(result).to be_a Concurrent::Maybe
        expect(result).to be_nothing
      end
    end

    context '.each' do
      pending
    end

    context '.go' do
      pending
    end

    context '.timer' do
      pending
    end
  end
end

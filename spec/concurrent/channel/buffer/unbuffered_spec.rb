require_relative 'base_shared'

module Concurrent::Channel::Buffer

  describe Unbuffered do

    specify { expect(subject).to be_blocking }

    subject { described_class.new }
    it_behaves_like :channel_buffer

    context '#put' do

      it 'blocks until a thread is ready to take' do
        subject # initialize on this thread
        bucket = Concurrent::AtomicReference.new(nil)
        t = Thread.new do
          subject.put(42)
          bucket.value = 42
        end

        t.join(0.1)

        before = bucket.value
        subject.take
        t.join(0.1)
        after = bucket.value

        expect(before).to be nil
        expect(after).to eq 42
        expect(t.status).to be false
      end
    end

    context '#take' do

      it 'blocks until not empty the returns the first item' do
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
    end

    context '#next' do

      it 'blocks when no putting and returns <item>, true when one arrives' do
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
        expect(after.last).to be false
        expect(t.status).to be false
      end

      it 'returns <item>, true when there are multiple putting' do
        subject # initialize on this thread
        threads = 2.times.collect do
          Thread.new do
            subject.put(42)
          end
        end
        threads.each {|t| t.join(0.1)}

        item, more = subject.next
        subject.poll # clear the channel

        expect(item).to eq 42
        expect(more).to be true
      end
    end

    context '#offer' do

      it 'returns false immediately when a put in in progress' do
        subject # initialize on this thread
        t = Thread.new do
          subject.put(:foo) # block the thread
        end
        t.join(0.1)

        ok = subject.offer(:bar)
        subject.poll # release the blocked thread

        expect(ok).to be false
      end

      it 'gives the item to a waiting taker and returns true' do
        subject # initialize on this thread
        bucket = Concurrent::AtomicReference.new(nil)
        t = Thread.new do
          bucket.value = subject.take
        end
        t.join(0.1)

        before = bucket.value
        ok = subject.offer(42)
        t.join(0.1)
        after = bucket.value

        expect(ok).to be true
        expect(before).to be nil
        expect(after).to eq 42
      end
    end
  end
end

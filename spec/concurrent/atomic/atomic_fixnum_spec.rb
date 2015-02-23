shared_examples :atomic_fixnum do

  context 'construction' do

    it 'sets the initial value' do
      expect(described_class.new(10).value).to eq 10
    end

    it 'defaults the initial value to zero' do
      expect(described_class.new.value).to eq 0
    end

    it 'raises en exception if the initial value is not a Fixnum' do
      expect {
        described_class.new(10.01)
      }.to raise_error
    end
  end

  context '#value' do

    it 'returns the current value' do
      counter = described_class.new(10)
      expect(counter.value).to eq 10
      counter.increment
      expect(counter.value).to eq 11
      counter.decrement
      expect(counter.value).to eq 10
    end
  end

  context '#value=' do

    it 'sets the #value to the given `Fixnum`' do
      atomic = described_class.new(0)
      atomic.value = 10
      expect(atomic.value).to eq 10
    end

    it 'returns the new value' do
      atomic = described_class.new(0)
      expect(atomic.value = 10).to eq 10
    end

    it 'raises and exception if the value is not a `Fixnum`' do
      atomic = described_class.new(0)
      expect {
        atomic.value = 'foo'
      }.to raise_error
    end
  end

  context '#increment' do

    it 'increases the value by one' do
      counter = described_class.new(10)
      3.times{ counter.increment }
      expect(counter.value).to eq 13
    end

    it 'returns the new value' do
      counter = described_class.new(10)
      expect(counter.increment).to eq 11
    end

    it 'is aliased as #up' do
      expect(described_class.new(10).up).to eq 11
    end
  end

  context '#decrement' do

    it 'decreases the value by one' do
      counter = described_class.new(10)
      3.times{ counter.decrement }
      expect(counter.value).to eq 7
    end

    it 'returns the new value' do
      counter = described_class.new(10)
      expect(counter.decrement).to eq 9
    end

    it 'is aliased as #down' do
      expect(described_class.new(10).down).to eq 9
    end
  end

  context '#compare_and_set' do

    it 'returns false if the value is not found' do
      expect(described_class.new(14).compare_and_set(2, 14)).to eq false
    end

    it 'returns true if the value is found' do
      expect(described_class.new(14).compare_and_set(14, 2)).to eq true
    end

    it 'sets if the value is found' do
      f = described_class.new(14)
      f.compare_and_set(14, 2)
      expect(f.value).to eq 2
    end

    it 'does not set if the value is not found' do
      f = described_class.new(14)
      f.compare_and_set(2, 12)
      expect(f.value).to eq 14
    end
  end
end

module Concurrent

  describe MutexAtomicFixnum do

    it_should_behave_like :atomic_fixnum

    specify 'construction is synchronized' do
      mutex = double('mutex')
      expect(Mutex).to receive(:new).once.with(no_args).and_return(mutex)
      described_class.new
    end

    specify 'value is synchronized' do
      mutex = double('mutex')
      allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
      expect(mutex).to receive(:lock)
      expect(mutex).to receive(:unlock)
      described_class.new.value
    end

    specify 'value= is synchronized' do
      mutex = double('mutex')
      allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
      expect(mutex).to receive(:lock)
      expect(mutex).to receive(:unlock)
      described_class.new.value = 10
    end

    specify 'increment is synchronized' do
      mutex = double('mutex')
      allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
      expect(mutex).to receive(:lock)
      expect(mutex).to receive(:unlock)
      described_class.new.increment
    end

    specify 'decrement is synchronized' do
      mutex = double('mutex')
      allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
      expect(mutex).to receive(:lock)
      expect(mutex).to receive(:unlock)
      described_class.new.decrement
    end

    specify 'compare_and_set is synchronized' do
      mutex = double('mutex')
      allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
      expect(mutex).to receive(:lock)
      expect(mutex).to receive(:unlock)
      described_class.new(14).compare_and_set(14, 2)
    end
  end

  if defined? Concurrent::CAtomicFixnum

    describe CAtomicFixnum do
      it_should_behave_like :atomic_fixnum
    end
  end

  if TestHelpers.jruby?

    describe JavaAtomicFixnum do
      it_should_behave_like :atomic_fixnum
    end
  end

  describe AtomicFixnum do
    if RUBY_ENGINE != 'ruby'
      it 'does not load the C extension' do
        expect(defined?(Concurrent::CAtomicFixnum)).to be_falsey
      end
    end

    if TestHelpers.jruby?
      it 'inherits from JavaAtomicFixnum' do
        expect(AtomicFixnum.ancestors).to include(JavaAtomicFixnum)
      end
    elsif defined? Concurrent::CAtomicFixnum
      it 'inherits from CAtomicFixnum' do
        expect(AtomicFixnum.ancestors).to include(CAtomicFixnum)
      end
    else
      it 'inherits from MutexAtomicFixnum' do
        expect(AtomicFixnum.ancestors).to include(MutexAtomicFixnum)
      end
    end
  end
end

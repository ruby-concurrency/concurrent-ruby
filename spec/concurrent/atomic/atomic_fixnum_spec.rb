require 'spec_helper'

share_examples_for :atomic_fixnum do

  context 'construction' do

    it 'sets the initial value' do
      described_class.new(10).value.should eq 10
    end

    it 'defaults the initial value to zero' do
      described_class.new.value.should eq 0
    end

    it 'raises en exception if the initial value is not a Fixnum' do
      lambda {
        described_class.new(10.01)
      }.should raise_error
    end
  end

  context '#value' do

    it 'returns the current value' do
      counter = described_class.new(10)
      counter.value.should eq 10
      counter.increment
      counter.value.should eq 11
      counter.decrement
      counter.value.should eq 10
    end
  end

  context '#value=' do

    it 'sets the #value to the given `Fixnum`' do
      atomic = described_class.new(0)
      atomic.value = 10
      atomic.value.should eq 10
    end

    it 'returns the new value' do
      atomic = described_class.new(0)
      (atomic.value = 10).should eq 10
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
      counter.value.should eq 13
    end

    it 'returns the new value' do
      counter = described_class.new(10)
      counter.increment.should eq 11
    end

    it 'is aliased as #up' do
      described_class.new(10).up.should eq 11
    end
  end

  context '#decrement' do

    it 'decreases the value by one' do
      counter = described_class.new(10)
      3.times{ counter.decrement }
      counter.value.should eq 7
    end

    it 'returns the new value' do
      counter = described_class.new(10)
      counter.decrement.should eq 9
    end

    it 'is aliased as #down' do
      described_class.new(10).down.should eq 9
    end
  end

  context '#compare_and_set' do

    it 'returns false if the value is not found' do
      described_class.new(14).compare_and_set(2, 14).should eq false
    end

    it 'returns true if the value is found' do
      described_class.new(14).compare_and_set(14, 2).should eq true
    end

    it 'sets if the value is found' do
      f = described_class.new(14)
      f.compare_and_set(14, 2)
      f.value.should eq 2
    end

    it 'does not set if the value is not found' do
      f = described_class.new(14)
      f.compare_and_set(2, 12)
      f.value.should eq 14
    end
  end
end

module Concurrent

  describe MutexAtomicFixnum do

    it_should_behave_like :atomic_fixnum

    specify 'construction is synchronized' do
      mutex = double('mutex')
      Mutex.should_receive(:new).once.with(no_args).and_return(mutex)
      described_class.new
    end

    specify 'value is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new.value
    end

    specify 'value= is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new.value = 10
    end

    specify 'increment is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new.increment
    end

    specify 'decrement is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new.decrement
    end

    specify 'compare_and_set is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new(14).compare_and_set(14, 2)
    end
  end

  if TestHelpers.jruby?

    describe JavaAtomicFixnum do
      it_should_behave_like :atomic_fixnum
    end
  end

  describe AtomicFixnum do
    if jruby?
      it 'inherits from JavaAtomicFixnum' do
        AtomicFixnum.ancestors.should include(JavaAtomicFixnum)
      end
    else
      it 'inherits from MutexAtomicFixnum' do
        AtomicFixnum.ancestors.should include(MutexAtomicFixnum)
      end
    end
  end
end

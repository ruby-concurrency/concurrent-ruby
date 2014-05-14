require 'spec_helper'

share_examples_for :atomic do

  context 'construction' do

    it 'sets the initial value' do
      described_class.new(:foo).value.should eq :foo
    end

    it 'defaults the initial value to nil' do
      described_class.new.value.should eq nil
    end
  end

  context '#value' do

    it 'returns the current value' do
      counter = described_class.new(:foo)
      counter.value.should eq :foo
    end
  end

  context '#value=' do

    it 'sets the #value to the given object' do
      atomic = described_class.new(:foo)
      atomic.value = :bar
      atomic.value.should eq :bar
    end

    it 'returns the new value' do
      atomic = described_class.new(:foo)
      (atomic.value = :bar).should eq :bar
    end
  end

  context '#modify' do

    it 'yields the current value' do
      atomic = described_class.new(:foo)
      current = []
      atomic.modify { |value| current << value }
      current.should eq [:foo]
    end

    it 'stores the value returned from the yield' do
      atomic = described_class.new(:foo)
      atomic.modify { |value| :bar }
      atomic.value.should eq :bar
    end

    it 'returns the new value' do
      atomic = described_class.new(:foo)
      atomic.modify{ |value| :bar }.should eq :bar
    end
  end

  context '#compare_and_set' do

    it 'returns false if the value is not found' do
      described_class.new(:foo).compare_and_set(:bar, :foo).should eq false
    end

    it 'returns true if the value is found' do
      described_class.new(:foo).compare_and_set(:foo, :bar).should eq true
    end

    it 'sets if the value is found' do
      f = described_class.new(:foo)
      f.compare_and_set(:foo, :bar)
      f.value.should eq :bar
    end

    it 'does not set if the value is not found' do
      f = described_class.new(:foo)
      f.compare_and_set(:bar, :baz)
      f.value.should eq :foo
    end
  end
end

module Concurrent

  describe MutexAtomic do

    it_should_behave_like :atomic

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

    specify 'modify is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new(:foo).modify { |value| value }
    end

    specify 'compare_and_set is synchronized' do
      mutex = double('mutex')
      Mutex.stub(:new).with(no_args).and_return(mutex)
      mutex.should_receive(:lock)
      mutex.should_receive(:unlock)
      described_class.new(14).compare_and_set(14, 2)
    end
  end

  describe Atomic do
    it 'inherits from MutexAtomic' do
      Atomic.ancestors.should include(MutexAtomic)
    end
  end
end

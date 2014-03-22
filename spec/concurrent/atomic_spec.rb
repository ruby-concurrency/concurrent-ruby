require 'spec_helper'
require_relative 'atomic_numeric_shared'

module Concurrent

  describe AtomicFixnum do

    it_should_behave_like :atomic_numeric
  end

  describe MutexAtomicFixnum do
    it_should_behave_like :atomic_numeric

    context 'construction' do

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        described_class.new.value
      end
    end

    context '#increment' do

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        described_class.new.increment
      end
    end

    context '#decrement' do

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        described_class.new.decrement
      end
    end

    context '#compare_and_set' do

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        described_class.new(14).compare_and_set(14, 2)
      end
    end
  end

  if jruby?
    describe JavaAtomicFixnum do
      it_should_behave_like :atomic_numeric
    end
  end
end

require 'spec_helper'

module Concurrent

  describe AtomicCounter do

    context 'construction' do

      it 'sets the initial value' do
        AtomicCounter.new(10).value.should eq 10
      end

      it 'defaults the initial value to zero' do
        AtomicCounter.new.value.should eq 0
      end

      it 'raises en exception if the initial value is not an integer' do
        lambda {
          AtomicCounter.new(10.01)
        }.should raise_error(ArgumentError)
      end
    end

    context '#value' do

      it 'returns the current value' do
        counter = AtomicCounter.new(10)
        counter.value.should eq 10
        counter.increment
        counter.value.should eq 11
        counter.decrement
        counter.value.should eq 10
      end

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        AtomicCounter.new.value
      end
    end

    context '#increment' do

      it 'increases the value by one' do
        counter = AtomicCounter.new(10)
        3.times{ counter.increment }
        counter.value.should eq 13
      end

      it 'returns the new value' do
        counter = AtomicCounter.new(10)
        counter.increment.should eq 11
      end

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        AtomicCounter.new.increment
      end

      it 'is aliased as #up' do
        AtomicCounter.new(10).up.should eq 11
      end
    end

    context '#decrement' do

      it 'decreases the value by one' do
        counter = AtomicCounter.new(10)
        3.times{ counter.decrement }
        counter.value.should eq 7
      end

      it 'returns the new value' do
        counter = AtomicCounter.new(10)
        counter.decrement.should eq 9
      end

      it 'is synchronized' do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:synchronize)
        AtomicCounter.new.decrement
      end

      it 'is aliased as #down' do
        AtomicCounter.new(10).down.should eq 9
      end
    end
  end
end

require 'spec_helper'

module Concurrent

  describe AtomicFixnum do

    context 'construction' do

      it 'sets the initial value' do
        AtomicFixnum.new(10).value.should eq 10
      end

      it 'defaults the initial value to zero' do
        AtomicFixnum.new.value.should eq 0
      end

      it 'raises en exception if the initial value is not a Fixnum' do
        lambda {
          AtomicFixnum.new(10.01)
        }.should raise_error(ArgumentError)
      end

      if jruby?

        it 'uses Java AtomicLong' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_not_receive(:synchronize)
          AtomicFixnum.new.value
        end

      else

        it 'is synchronized' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_receive(:synchronize)
          AtomicFixnum.new.value
        end

      end

    end

    context '#value' do

      it 'returns the current value' do
        counter = AtomicFixnum.new(10)
        counter.value.should eq 10
        counter.increment
        counter.value.should eq 11
        counter.decrement
        counter.value.should eq 10
      end

    end

    context '#increment' do

      it 'increases the value by one' do
        counter = AtomicFixnum.new(10)
        3.times{ counter.increment }
        counter.value.should eq 13
      end

      it 'returns the new value' do
        counter = AtomicFixnum.new(10)
        counter.increment.should eq 11
      end

      it 'is aliased as #up' do
        AtomicFixnum.new(10).up.should eq 11
      end

      if jruby?

        it 'does not use Mutex class' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_not_receive(:synchronize)
          AtomicFixnum.new.increment
        end

      else

        it 'is synchronized' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_receive(:synchronize)
          AtomicFixnum.new.increment
        end

      end

    end

    context '#decrement' do

      it 'decreases the value by one' do
        counter = AtomicFixnum.new(10)
        3.times{ counter.decrement }
        counter.value.should eq 7
      end

      it 'returns the new value' do
        counter = AtomicFixnum.new(10)
        counter.decrement.should eq 9
      end

      it 'is aliased as #down' do
        AtomicFixnum.new(10).down.should eq 9
      end

      if jruby?

        it 'does not use Mutex class' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_not_receive(:synchronize)
          AtomicFixnum.new.decrement
        end

      else

        it 'is synchronized' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_receive(:synchronize)
          AtomicFixnum.new.decrement
        end

      end

    end

    context '#compare_and_set' do

      it 'returns false if the value is not found' do
        AtomicFixnum.new(14).compare_and_set(2, 14).should eq false
      end

      it 'returns true if the value is found' do
        AtomicFixnum.new(14).compare_and_set(14, 2).should eq true
      end

      it 'sets if the value is found' do
        f = AtomicFixnum.new(14)
        f.compare_and_set(14, 2)
        f.value.should eq 2
      end

      it 'does not set if the value is not found' do
        f = AtomicFixnum.new(14)
        f.compare_and_set(2, 12)
        f.value.should eq 14
      end

      if jruby?

        it 'does not use Mutex class' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_not_receive(:synchronize)
          AtomicFixnum.new(14).compare_and_set(14, 2)
        end

      else

        it 'is synchronized' do
          mutex = double('mutex')
          Mutex.stub(:new).with(no_args).and_return(mutex)
          mutex.should_receive(:synchronize)
          AtomicFixnum.new(14).compare_and_set(14, 2)
        end

      end

    end

  end
end

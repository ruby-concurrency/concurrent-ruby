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

        it 'supports JRuby-optimizations' do
          java.util.concurrent.atomic.AtomicLong.should_receive(:new).with(any_args)
          AtomicFixnum.new(10)
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

    end
  end
end

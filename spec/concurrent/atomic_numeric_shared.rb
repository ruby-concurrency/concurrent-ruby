require 'spec_helper'

share_examples_for :atomic_numeric do

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
      }.should raise_error(ArgumentError)
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
      }.to raise_error(ArgumentError)
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

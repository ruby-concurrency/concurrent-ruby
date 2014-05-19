require 'spec_helper'

module Concurrent

  describe Observable do

    let (:described_class) do
      Class.new do
        include Concurrent::Observable
        public :observers, :observers=
      end
    end

    let(:observer_set) { double(:observer_set) }
    subject { described_class.new }

    before(:each) do
      subject.observers = observer_set
    end

    it 'does not initialize set by by default' do
      described_class.new.observers.should be_nil
    end

    it 'uses the given observer set' do
      expected          = CopyOnWriteObserverSet.new
      subject.observers = expected
      subject.observers.should eql expected
    end

    it 'delegates #add_observer' do
      observer_set.should_receive(:add_observer).with(:observer).and_return { |v| v }
      subject.add_observer(:observer).should eq :observer
    end

    it 'delegates #with_observer' do
      observer_set.should_receive(:add_observer).with(:observer).and_return { |v| v }
      subject.with_observer(:observer).should eq subject
    end

    it 'delegates #delete_observer' do
      observer_set.should_receive(:delete_observer).with(:observer)
      subject.delete_observer(:observer)
    end

    it 'delegates #delete_observers' do
      observer_set.should_receive(:delete_observers).with(no_args)
      subject.delete_observers
    end

    it 'delegates #count_observers' do
      observer_set.should_receive(:count_observers).with(no_args)
      subject.count_observers
    end
  end
end

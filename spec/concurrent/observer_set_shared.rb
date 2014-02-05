require 'spec_helper'

shared_examples "an observer set" do

  let (:observer_set) { described_class.new }
  let (:observer) { double('observer') }
  let (:another_observer) { double('another observer') }

  describe '#add_observer' do

    context 'with argument' do
      it 'should return the passed function' do
        observer_set.add_observer(observer, :a_method).should eq(:a_method)
      end
    end

    context 'without arguments' do
      it 'should return the default function' do
        observer_set.add_observer(observer).should eq(:update)
      end
    end
  end

  describe '#notify_observers' do
    it 'should return the observer set' do
      observer_set.notify_observers.should be(observer_set)
    end

    context 'with a single observer' do
      it 'should update a registered observer without arguments' do
        expect(observer).to receive(:update).with(no_args)

        observer_set.add_observer(observer)

        observer_set.notify_observers
      end

      it 'should update a registered observer with arguments' do
        expect(observer).to receive(:update).with(1, 2, 3)

        observer_set.add_observer(observer)

        observer_set.notify_observers(1, 2, 3)
      end

      it 'should notify an observer using the chosen method' do
        expect(observer).to receive(:another_method).with('a string arg')

        observer_set.add_observer(observer, :another_method)

        observer_set.notify_observers('a string arg')
      end

      it 'should notify an observer once using the last added method' do
        expect(observer).to receive(:another_method).with(any_args).never
        expect(observer).to receive(:yet_another_method).with('a string arg')

        observer_set.add_observer(observer, :another_method)
        observer_set.add_observer(observer, :yet_another_method)

        observer_set.notify_observers('a string arg')
      end

      it 'can be called many times' do
        expect(observer).to receive(:update).with(:an_arg).twice
        expect(observer).to receive(:update).with(no_args).once

        observer_set.add_observer(observer)

        observer_set.notify_observers(:an_arg)
        observer_set.notify_observers
        observer_set.notify_observers(:an_arg)
      end
    end

    context 'with many observers' do
      it 'should notify all observer using the chosen method' do
        expect(observer).to receive(:a_method).with(4, 'a')
        expect(another_observer).to receive(:update).with(4, 'a')

        observer_set.add_observer(observer, :a_method)
        observer_set.add_observer(another_observer)

        observer_set.notify_observers(4, 'a')
      end
    end
  end

  context '#count_observers' do
    it 'should be zero after initialization' do
      observer_set.count_observers.should eq 0
    end

    it 'should be 1 after the first observer is added' do
      observer_set.add_observer(observer)
      observer_set.count_observers.should eq 1
    end

    it 'should be 1 if the same observer is added many times' do
      observer_set.add_observer(observer)
      observer_set.add_observer(observer, :another_method)
      observer_set.add_observer(observer, :yet_another_method)

      observer_set.count_observers.should eq 1
    end

    it 'should be equal to the number of unique observers' do
      observer_set.add_observer(observer)
      observer_set.add_observer(another_observer)
      observer_set.add_observer(double('observer 3'))
      observer_set.add_observer(double('observer 4'))

      observer_set.count_observers.should eq 4
    end
  end

  describe '#delete_observer' do
    it 'should not notify a deleted observer' do
      expect(observer).to receive(:update).never

      observer_set.add_observer(observer)
      observer_set.delete_observer(observer)

      observer_set.notify_observers
    end

    it 'can delete a non added observer' do
      observer_set.delete_observer(observer)
    end

    it 'should return the observer' do
      observer_set.delete_observer(observer).should be(observer)
    end
  end

  describe '#delete_observers' do
    it 'should remove all observers' do
      expect(observer).to receive(:update).never
      expect(another_observer).to receive(:update).never

      observer_set.add_observer(observer)
      observer_set.add_observer(another_observer)

      observer_set.delete_observers

      observer_set.notify_observers
    end

    it 'should return the observer set' do
      observer_set.delete_observers.should be(observer_set)
    end
  end

  describe '#notify_and_delete_observers' do
    before(:each) do
      observer_set.add_observer(observer, :a_method)
      observer_set.add_observer(another_observer)

      expect(observer).to receive(:a_method).with('args').once
      expect(another_observer).to receive(:update).with('args').once
    end

    it 'should notify all observers' do
      observer_set.notify_and_delete_observers('args')
    end

    it 'should clear observers' do
      observer_set.notify_and_delete_observers('args')

      observer_set.count_observers.should eq(0)
    end

    it 'can be called many times without any other notification' do
      observer_set.notify_and_delete_observers('args')
      observer_set.notify_and_delete_observers('args')
      observer_set.notify_and_delete_observers('args')
    end

    it 'should return the observer set' do
      observer_set.notify_and_delete_observers('args').should be(observer_set)
    end
  end

end

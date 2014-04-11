require 'spec_helper'

share_examples_for :priority_queue do

  subject{ described_class.new }

  context '#initialize' do

    it 'sorts from high to low when :order is :max' do
      subject = described_class.from_list([2, 1, 4, 5, 3, 0], order: :max)
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
    end

    it 'sorts from high to low when :order is :high' do
      subject = described_class.new(order: :high)
      [2, 1, 4, 5, 3, 0].each{|item| subject << item }
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
    end

    it 'sorts from low to high when :order is :min' do
      subject = described_class.from_list([2, 1, 4, 5, 3, 0], order: :min)
      subject.pop.should eq 0
      subject.pop.should eq 1
      subject.pop.should eq 2
    end

    it 'sorts from low to high when :order is :low' do
      subject = described_class.new(order: :low)
      [2, 1, 4, 5, 3, 0].each{|item| subject << item }
      subject.pop.should eq 0
      subject.pop.should eq 1
      subject.pop.should eq 2
    end

    it 'sorts from high to low by default' do
      subject = described_class.new
      subject = described_class.from_list([2, 1, 4, 5, 3, 0])
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
    end
  end

  context '#clear' do

    it 'removes all items from a populated queue' do
      10.times{|i| subject << i}
      subject.clear
      subject.should be_empty
    end

    it 'has no effect on an empty queue' do
      subject.clear
      subject.should be_empty
    end

    specify { subject.clear.should be_true }
  end

  context '#delete' do

    it 'deletes the requested item when found' do
      10.times{|item| subject << item }
      subject.delete(5)
      subject.pop.should eq 9
      subject.pop.should eq 8
      subject.pop.should eq 7
      subject.pop.should eq 6
      subject.pop.should eq 4
      subject.pop.should eq 3
      subject.pop.should eq 2
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    it 'deletes the requested item when it is the first element' do
      10.times{|item| subject << item }
      subject.delete(9)
      subject.length.should eq 9
      subject.pop.should eq 8
      subject.pop.should eq 7
      subject.pop.should eq 6
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
      subject.pop.should eq 2
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    it 'deletes the requested item when it is the last element' do
      10.times{|item| subject << item }
      subject.delete(2)
      subject.length.should eq 9
      subject.pop.should eq 9
      subject.pop.should eq 8
      subject.pop.should eq 7
      subject.pop.should eq 6
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    it 'deletes multiple matching items when present' do
      [2, 1, 2, 2, 2, 3, 2].each{|item| subject << item }
      subject.delete(2)
      subject.pop.should eq 3
      subject.pop.should eq 1
    end

    it 'returns true when found' do
      10.times{|i| subject << i}
      subject.delete(2).should be_true
    end

    it 'returns false when not found' do
      10.times{|i| subject << i}
      subject.delete(100).should be_false
    end

    it 'returns false when called on an empty queue' do
      subject.delete(:foo).should be_false
    end
  end

  context '#empty?' do

    it 'returns true for an empty queue' do
      subject.should be_empty
    end

    it 'returns false for a populated queue' do
      10.times{|i| subject << i}
      subject.should_not be_empty
    end
  end

  context '#include?' do

    it 'returns true if the item is found' do
      10.times{|i| subject << i}
      subject.should include(5)
    end

    it 'returns false if the item is not found' do
      10.times{|i| subject << i}
      subject.should_not include(50)
    end

    it 'returns false when the queue is empty' do
      subject.should_not include(1)
    end

    it 'is aliased as #has_priority?' do
      10.times{|i| subject << i}
      subject.should have_priority(5)
    end
  end

  context '#length' do

    it 'returns the length of a populated queue' do
      10.times{|i| subject << i}
      subject.length.should eq 10
    end

    it 'returns zero when the queue is empty' do
      subject.length.should eq 0
    end

    it 'is aliased as #size' do
      10.times{|i| subject << i}
      subject.size.should eq 10
    end
  end

  context '#peek' do

    it 'returns the item at the head of the queue' do
      10.times{|i| subject << i}
      subject.peek.should eq 9
    end

    it 'does not remove the item from the queue' do
      10.times{|i| subject << i}
      subject.peek
      subject.length.should eq 10
      subject.should include(9)
    end

    it 'returns nil when the queue is empty' do
      subject.peek.should be_nil
    end
  end

  context '#pop' do

    it 'returns the item at the head of the queue' do
      10.times{|i| subject << i}
      subject.pop.should eq 9
    end

    it 'removes the item from the queue' do
      10.times{|i| subject << i}
      subject.pop
      subject.length.should eq 9
      subject.should_not include(9)
    end

    it 'returns nil when the queue is empty' do
      subject.pop.should be_nil
    end

    it 'is aliased as #deq' do
      10.times{|i| subject << i}
      subject.deq.should eq 9
    end

    it 'is aliased as #shift' do
      10.times{|i| subject << i}
      subject.shift.should eq 9
    end
  end

  context '#push' do

    it 'adds the item to the queue' do
      subject.push(1)
      subject.should include(1)
    end

    it 'sorts the new item in priority order' do
      3.times{|i| subject << i}
      subject.pop.should eq 2
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    it 'arbitrarily orders equal items with respect to each other' do
      3.times{|i| subject << i}
      subject.push(1)
      subject.pop.should eq 2
      subject.pop.should eq 1
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    specify { subject.push(10).should be_true }

    it 'is aliased as <<' do
      subject << 1
      subject.should include(1)
    end

    it 'is aliased as enq' do
      subject.enq(1)
      subject.should include(1)
    end
  end

  context '.from_list' do

    it 'creates an empty queue from an empty list' do
      subject = described_class.from_list([])
      subject.should be_empty
    end

    it 'creates a sorted, populated queue from an Array' do
      subject = described_class.from_list([2, 1, 4, 5, 3, 0])
      subject.pop.should eq 5
      subject.pop.should eq 4
      subject.pop.should eq 3
      subject.pop.should eq 2
      subject.pop.should eq 1
      subject.pop.should eq 0
    end

    it 'creates a sorted, populated queue from a Hash' do
      subject = described_class.from_list(two: 2, one: 1, three: 3, zero: 0)
      subject.length.should eq 4
    end
  end
end

module Concurrent

  describe MutexPriorityQueue do

    it_should_behave_like :priority_queue
  end

  if jruby?

    describe JavaPriorityQueue do

      it_should_behave_like :priority_queue
    end
  end

  describe PriorityQueue do
    if jruby?
      it 'inherits from JavaPriorityQueue' do
        PriorityQueue.ancestors.should include(JavaPriorityQueue)
      end
    else
      it 'inherits from MutexPriorityQueue' do
        PriorityQueue.ancestors.should include(MutexPriorityQueue)
      end
    end
  end
end

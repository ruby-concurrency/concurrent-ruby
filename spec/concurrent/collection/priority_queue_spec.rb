require 'spec_helper'

share_examples_for :priority_queue do

  context '#initialize' do
    pending
  end

  context '#clear' do
    pending
  end

  context '#empty?' do
    pending
  end

  context '#length' do
    pending
  end

  context '#num_waiting' do
    pending
  end

  context '#peek' do
    pending
  end

  context '#pop' do
    pending
  end

  context '#push' do
    pending
  end
end

module Concurrent

  describe MutexPriorityQueue do

    subject { MutexPriorityQueue.new }

    it_should_behave_like :priority_queue
  end

  if jruby?

    describe JavaPriorityQueue do

      subject { JavaPriorityQueue.new }

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

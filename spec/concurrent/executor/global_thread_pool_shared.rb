require 'spec_helper'

share_examples_for :global_thread_pool do

  context '#post' do

    it 'raises an exception if no block is given' do
      lambda {
        subject.post
      }.should raise_error(ArgumentError)
    end

    it 'returns true when the block is added to the queue' do
      subject.post{ nil }.should be_true
    end

    it 'calls the block with the given arguments' do
      latch = Concurrent::CountDownLatch.new(1)
      expected = nil
      subject.post(1, 2, 3) do |a, b, c|
        expected = [a, b, c]
        latch.count_down
      end
      latch.wait(0.2)
      expected.should eq [1, 2, 3]
    end

    it 'aliases #<<' do
      latch = Concurrent::CountDownLatch.new(1)
      subject << proc { latch.count_down }
      latch.wait(0.2)
      latch.count.should eq 0
    end
  end
end

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
      @expected = nil
      subject.post(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      sleep(0.1)
      @expected.should eq 6
    end

    it 'aliases #<<' do
      @expected = false
      subject << proc { @expected = true }
      sleep(0.1)
      @expected.should be_true
    end
  end
end

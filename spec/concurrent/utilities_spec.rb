require 'spec_helper'

describe 'utilities' do

  context '#atomic' do

    it 'calls the block' do
      @expected = false
      atomic{ @expected = true }
      @expected.should be_true
    end

    it 'passes all arguments to the block' do
      @expected = nil
      atomic(1, 2, 3, 4) do |a, b, c, d|
        @expected = [a, b, c, d]
      end
      @expected.should eq [1, 2, 3, 4]
    end

    it 'returns the result of the block' do
      expected = atomic{ 'foo' }
      expected.should eq 'foo'
    end

    it 'raises an exception if no block is given' do
      lambda {
        atomic()
      }.should raise_error
    end

    it 'creates a new Fiber' do
      fiber = Fiber.new{ 'foo' }
      Fiber.should_receive(:new).with(no_args()).and_return(fiber)
      atomic{ 'foo' }
    end

    it 'immediately runs the Fiber' do
      fiber = Fiber.new{ 'foo' }
      Fiber.stub(:new).with(no_args()).and_return(fiber)
      fiber.should_receive(:resume).with(no_args())
      atomic{ 'foo' }
    end
  end
end

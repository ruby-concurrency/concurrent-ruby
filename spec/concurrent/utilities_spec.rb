require 'spec_helper'
require 'thread'

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
      }.should raise_error(ArgumentError)
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

  context Mutex do

     context '#sync_with_timeout' do

       it 'returns the result of the block if a lock is obtained before timeout' do
         mutex = Mutex.new
         result = mutex.sync_with_timeout(30){ 42 }
         result.should eq 42
       end

       it 'raises Timeout::Error if the timeout is exceeded' do
         mutex = Mutex.new
         thread = Thread.new{ mutex.synchronize{ sleep(30) } }
         sleep(0.1)
         lambda {
           mutex.sync_and_wait(1)
         }.should raise_error(NoMethodError)
         Thread.kill(thread)
       end

       it 'raises an exception if no block given' do
         lambda {
           Mutex.new.sync_with_timeout()
         }.should raise_error(ArgumentError)
       end
     end
  end
end

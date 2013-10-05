require 'spec_helper'
require_relative 'runnable_shared'

module Concurrent

  describe Channel do

    subject { Channel.new }
    let(:runnable) { Channel }

    it_should_behave_like :runnable

    after(:each) do
      subject.stop
      @thread.kill unless @thread.nil?
    end

    context '#post' do

      it 'returns false when not running' do
        subject.post.should be_false
      end

      it 'pushes a message onto the queue' do
        @expected = false
        channel = Channel.new{|msg| @expected = msg }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        channel.post(true)
        sleep(0.1)
        @expected.should be_true
        channel.stop
      end

      it 'returns the current size of the queue' do
        channel = Channel.new{|msg| sleep }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        3.times do |i|
          channel.post(true).should == i+1
        end
        channel.stop
      end

      it 'is aliased a <<' do
        @expected = false
        channel = Channel.new{|msg| @expected = msg }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        channel << true
        sleep(0.1)
        @expected.should be_true
        channel.stop
      end
    end

    context '#run' do

      it 'empties the queue' do
        @thread = Thread.new{ subject.run }
        sleep(0.1)
        q = subject.instance_variable_get(:@queue)
        q.size.should == 0
      end
    end

    context '#stop' do

      it 'empties the queue' do
        channel = Channel.new{|msg| sleep }
        @thread = Thread.new{ channel.run }
        10.times { channel.post(true) }
        sleep(0.1)
        channel.stop
        sleep(0.1)
        q = channel.instance_variable_get(:@queue)
        q.size.should == 0
      end

      it 'pushes a :stop message onto the queue' do
        @thread = Thread.new{ subject.run }
        sleep(0.1)
        q = subject.instance_variable_get(:@queue)
        q.should_receive(:push).once.with(:stop)
        subject.stop
        sleep(0.1)
      end
    end

    context 'message handling' do

      it 'runs the constructor block once for every message' do
        @expected = 0
        channel = Channel.new{|msg| @expected += 1 }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        10.times { channel.post(true) }
        sleep(0.1)
        @expected.should eq 10
        channel.stop
      end

      it 'passes the message to the block' do
        @expected = []
        channel = Channel.new{|msg| @expected << msg }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        10.times {|i| channel.post(i) }
        sleep(0.1)
        channel.stop
        @expected.should eq (0..9).to_a
      end
    end

    context 'exception handling' do

      it 'supresses exceptions thrown when handling messages' do
        channel = Channel.new{|msg| raise StandardError }
        @thread = Thread.new{ channel.run }
        expect {
          sleep(0.1)
          10.times { channel.post(true) }
        }.not_to raise_error
        channel.stop
      end

      it 'calls the errorback with the time, message, and exception' do
        @expected = []
        errorback = proc{|*args| @expected = args }
        channel = Channel.new(errorback){|msg| raise StandardError }
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        channel.post(100)
        sleep(0.1)
        @expected[0].should be_a(Time)
        @expected[1].should == [100]
        @expected[2].should be_a(StandardError)
        channel.stop
      end
    end

    context 'observer notification' do

      let(:observer) do
        Class.new {
          attr_reader :notice
          def update(*args) @notice = args; end
        }.new
      end

      it 'notifies observers when a message is successfully handled' do
        observer.should_receive(:update).exactly(10).times.with(any_args())
        subject.add_observer(observer)
        @thread = Thread.new{ subject.run }
        sleep(0.1)
        10.times { subject.post(true) }
        sleep(0.1)
      end

      it 'does not notify observers when a message raises an exception' do
        observer.should_not_receive(:update).with(any_args())
        channel = Channel.new{|msg| raise StandardError }
        channel.add_observer(observer)
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        10.times { channel.post(true) }
        sleep(0.1)
        channel.stop
      end

      it 'passes the time, message, and result to the observer' do
        channel = Channel.new{|*msg| msg }
        channel.add_observer(observer)
        @thread = Thread.new{ channel.run }
        sleep(0.1)
        channel.post(100)
        sleep(0.1)
        observer.notice[0].should be_a(Time)
        observer.notice[1].should == [100]
        observer.notice[2].should == [100]
        channel.stop
      end
    end

    context 'subclassing' do
      pending
    end
  end
end

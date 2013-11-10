require 'spec_helper'

share_examples_for :postable do

  after(:each) do
    subject.stop
    @thread.kill unless @thread.nil?
    sleep(0.1)
  end

  context '#post' do

    it 'returns false when not running' do
      subject.post.should be_false
    end

    it 'pushes a message onto the queue' do
      @expected = false
      postable = postable_class.new{|msg| @expected = msg }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      postable.post(true)
      @thread.join(0.1)
      @expected.should be_true
      postable.stop
    end

    it 'returns the current size of the queue' do
      postable = postable_class.new{|msg| sleep }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      postable.post(true).should == 1
      @thread.join(0.1)
      postable.post(true).should == 1
      @thread.join(0.1)
      postable.post(true).should == 2
      postable.stop
    end

    it 'is aliased a <<' do
      @expected = false
      postable = postable_class.new{|msg| @expected = msg }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      postable << true
      @thread.join(0.1)
      @expected.should be_true
      postable.stop
    end
  end

  context '#post?' do

    it 'returns nil when not running' do
      subject.post?.should be_false
    end

    it 'returns an Obligation' do
      postable = postable_class.new{ nil }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      obligation = postable.post?(nil)
      obligation.should be_a(Concurrent::Obligation)
      postable.stop
    end

    it 'fulfills the obligation on success' do
      postable = postable_class.new{|msg| @expected = msg }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      obligation = postable.post?(42)
      @thread.join(0.1)
      obligation.should be_fulfilled
      obligation.value.should == 42
      postable.stop
    end

    it 'rejects the obligation on failure' do
      postable = postable_class.new{|msg| raise StandardError.new('Boom!') }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      obligation = postable.post?(42)
      @thread.join(0.1)
      obligation.should be_rejected
      obligation.reason.should be_a(StandardError)
      postable.stop
    end
  end

  context '#post!' do

    it 'raises Concurrent::Runnable::LifecycleError when not running' do
      expect {
        subject.post!(1)
      }.to raise_error(Concurrent::Runnable::LifecycleError)
    end

    it 'blocks for up to the given number of seconds' do
      postable = postable_class.new{|msg| sleep }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      start = Time.now.to_i
      expect {
        postable.post!(2, nil)
      }.to raise_error
      elapsed = Time.now.to_i - start
      elapsed.should >= 2
      postable.stop
    end

    it 'raises Concurrent::TimeoutError when seconds is zero' do
      postable = postable_class.new{|msg| 42 }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      expect {
        postable.post!(0, nil)
      }.to raise_error(Concurrent::TimeoutError)
      postable.stop
    end

    it 'raises Concurrent::TimeoutError on timeout' do
      postable = postable_class.new{|msg| sleep }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      expect {
        postable.post!(1, nil)
      }.to raise_error(Concurrent::TimeoutError)
      postable.stop
    end

    it 'bubbles the exception on error' do
      postable = postable_class.new{|msg| raise StandardError.new('Boom!') }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      expect {
        postable.post!(1, nil)
      }.to raise_error(StandardError)
      postable.stop
    end

    it 'returns the result on success' do
      postable = postable_class.new{|msg| 42 }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      expected = postable.post!(1, nil)
      expected.should == 42
      postable.stop
    end

    it 'attempts to cancel the operation on timeout' do
      @expected = 0
      postable = postable_class.new{|msg| sleep(0.5); @expected += 1 }
      @thread = Thread.new{ postable.run }
      @thread.join(0.1)
      postable.post(nil) # block the postable
      expect {
        postable.post!(0.1, nil)
      }.to raise_error(Concurrent::TimeoutError)
      sleep(1.5)
      @expected.should == 1
      postable.stop
    end
  end

  context '#forward' do

    let(:observer) { double('observer') }

    before(:each) do
      @sender = Thread.new{ sender.run }
      @receiver = Thread.new{ receiver.run }
      @sender.join(0.1)
      @receiver.join(0.1)
    end

    after(:each) do
      sender.stop
      receiver.stop
      sleep(0.1)
      @sender.kill unless @sender.nil?
      @receiver.kill unless @receiver.nil?
    end

    it 'returns false when sender not running' do
      sender.stop
      sleep(0.1)
      sender.forward(receiver).should be_false
    end

    it 'forwards the result to the receiver on success' do
      receiver.should_receive(:post).with(42)
      sender.forward(receiver, 42)
      sleep(0.1)
    end

    it 'does not forward on exception' do
      receiver.should_not_receive(:post).with(42)
      sender.forward(receiver, StandardError.new)
      sleep(0.1)
    end

    it 'notifies observers on success' do
      observer.should_receive(:update).with(any_args())
      sender.add_observer(observer)
      sender.forward(receiver, 42)
      sleep(0.1)
    end

    it 'notifies observers on exception' do
      observer.should_not_receive(:update).with(any_args())
      sender.add_observer(observer)
      sender.forward(receiver, StandardError.new)
      sleep(0.1)
    end
  end
end

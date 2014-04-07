require 'spec_helper'

def shared_actor_test_class
  Class.new do
    include Concurrent::ActorContext

    attr_reader :argv

    def initialize(*args)
      @argv = args
    end

    def receive(*msg)
      case msg.first
      when :poison
        raise StandardError
      when :bullet
        raise Exception
      when :terminate
        Thread.current.kill
      when :sleep
        sleep(msg.last)
      when :check
        msg[1].set(msg.last)
      else
        msg.first
      end
    end
  end
end

share_examples_for :actor_ref do

  it 'includes ActorRef' do
    subject.should be_a Concurrent::ActorRef
  end

  context 'running and shutdown' do

    specify { subject.should respond_to :shutdown }

    specify { subject.should be_running }

    specify { subject.should_not be_shutdown }

    specify do
      subject.shutdown
      sleep(0.1)
      subject.should be_shutdown
    end
  end

  context '#post' do

    it 'raises an exception when the message is empty' do
      expect {
        subject.post
      }.to raise_error(ArgumentError)
    end

    it 'returns an IVar' do
      subject.post(:foo).should be_a Concurrent::IVar
    end

    it 'fulfills the IVar when message is processed' do
      ivar = subject.post(:foo)
      sleep(0.1)
      ivar.should be_fulfilled
      ivar.value.should eq :foo
    end

    it 'rejects the IVar when message processing fails' do
      ivar = subject.post(:poison)
      sleep(0.1)
      ivar.should be_rejected
      ivar.reason.should be_a StandardError
    end
  end

  context '#<<' do

    it 'posts the message' do
      ivar = Concurrent::IVar.new
      subject << [:check, ivar, :foo]
      ivar.value(0.1).should eq :foo
    end

    it 'returns self' do
      (subject << [1,2,3,4]).should eq subject
    end
  end

  context '#post with callback' do

    specify 'on success calls the callback with time and value' do
      expected_value = expected_reason = nil
      subject.post(:foo) do |time, value, reason|
        expected_value = value
        expected_reason = reason
      end
      sleep(0.1)

      expected_value.should eq :foo
      expected_reason.should be_nil
    end

    specify 'on failure calls the callback with time and reason' do
      expected_value = expected_reason = nil
      subject.post(:poison) do |time, value, reason|
        expected_value = value
        expected_reason = reason
      end
      sleep(0.1)

      expected_value.should be_nil
      expected_reason.should be_a StandardError
    end

    it 'supresses exceptions thrown by the callback' do
      expected = nil
      subject.post(:foo){|time, value, reason| raise StandardError }
      sleep(0.1)

      subject.post(:bar){|time, value, reason| expected = value }
      sleep(0.1)

      expected.should eq :bar
    end
  end

  context '#post!' do

    it 'raises an exception when the message is empty' do
      expect {
        subject.post!(1)
      }.to raise_error(ArgumentError)
    end

    it 'blocks for up to the given number of seconds' do
      start = Time.now.to_f
      begin
        subject.post!(1, :sleep, 2)
      rescue
      end
      delta = Time.now.to_f - start
      delta.should >= 1
      delta.should <= 2
    end

    it 'blocks forever when the timeout is nil' do
      start = Time.now.to_f
      begin
        subject.post!(nil, :sleep, 1)
      rescue
      end
      delta = Time.now.to_f - start
      delta.should > 1
    end

    it 'raises a TimeoutError when timeout is zero' do
      expect {
        subject.post!(0, :foo)
      }.to raise_error(Concurrent::TimeoutError)
    end

    it 'raises a TimeoutError when the timeout is reached' do
      expect {
        subject.post!(1, :sleep, 10)
      }.to raise_error(Concurrent::TimeoutError)
    end

    it 'returns the result of success processing' do
      subject.post!(1, :foo).should eq :foo
    end

    it 'bubbles exceptions thrown during processing' do
      expect {
        subject.post!(1, :poison)
      }.to raise_error(StandardError)
    end
  end

  context '#join' do

    it 'blocks until shutdown when no limit is given' do
      start = Time.now
      subject << :foo # start the actor's thread
      Thread.new{ sleep(1); subject.shutdown }
      subject.join
      stop = Time.now

      subject.should be_shutdown
      stop.should >= start + 1
      stop.should <= start + 2
    end

    it 'blocks for no more than the given number of seconds' do
      start = Time.now
      subject << :foo # start the actor's thread
      Thread.new{ sleep(5); subject.shutdown }
      subject.join(1)
      stop = Time.now

      stop.should >= start + 1
      stop.should <= start + 2
    end

    it 'returns true when shutdown has completed before timeout' do
      subject << :foo # start the actor's thread
      Thread.new{ sleep(1); subject.shutdown }
      subject.join.should be_true
    end

    it 'returns false on timeout' do
      subject << :foo # start the actor's thread
      Thread.new{ sleep(5); subject.shutdown }
      subject.join(1).should be_false
    end

    it 'returns immediately when already shutdown' do
      start = Time.now
      subject << :foo # start the actor's thread
      sleep(0.1)
      subject.shutdown
      sleep(0.1)

      start = Time.now
      subject.join
      Time.now.should >= start
      Time.now.should <= start + 0.1
    end
  end

  context '#on_error' do

    specify 'is not called on success' do
      actor = subject.instance_variable_get(:@actor)
      actor.should_not_receive(:on_error).with(any_args)
      subject.post(:foo)
      sleep(0.1)
    end

    specify 'is called when a message raises an exception' do
      actor = subject.instance_variable_get(:@actor)
      actor.should_receive(:on_error).
        with(anything, [:poison], an_instance_of(StandardError))
      subject.post(:poison)
      sleep(0.1)
    end
  end

  context 'observation' do

    let(:observer_class) do
      Class.new do
        attr_reader :time, :msg, :value, :reason
        def update(time, msg, value, reason)
          @msg = msg
          @time = time
          @value = value
          @reason = reason
        end
      end
    end

    it 'notifies observers' do
      o1 = observer_class.new
      o2 = observer_class.new

      subject.add_observer(o1)
      subject.add_observer(o2)

      subject << :foo
      sleep(0.1)

      o1.value.should eq :foo
      o1.reason.should be_nil

      o2.value.should eq :foo
      o2.reason.should be_nil
    end

    it 'does not notify removed observers' do
      o1 = observer_class.new
      o2 = observer_class.new

      subject.add_observer(o1)
      subject.add_observer(o2)

      subject << :foo
      sleep(0.1)

      subject.delete_observer(o1)
      subject << :bar
      sleep(0.1)
      o1.value.should_not eq :bar

      subject.delete_observers
      subject << :baz
      sleep(0.1)
      o1.value.should_not eq :baz
    end
  end
end

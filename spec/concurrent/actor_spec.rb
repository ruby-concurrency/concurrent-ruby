require 'spec_helper'
require_relative 'runnable_shared'

module Concurrent

  describe Actor do

    let(:actor_class) do
      Class.new(Actor) do
        attr_reader :last_message
        def initialize(&block)
          @task = block
          super()
        end
        def act(*message)
          @last_message = message
          @task.call(*message) unless @task.nil?
        end
      end
    end

    subject { Class.new(actor_class).new }

    it_should_behave_like :runnable

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
        actor = actor_class.new{|msg| @expected = msg }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        actor.post(true)
        @thread.join(0.1)
        @expected.should be_true
        actor.stop
      end

      it 'returns the current size of the queue' do
        actor = actor_class.new{|msg| sleep }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        actor.post(true).should == 1
        @thread.join(0.1)
        actor.post(true).should == 1
        @thread.join(0.1)
        actor.post(true).should == 2
        actor.stop
      end

      it 'is aliased a <<' do
        @expected = false
        actor = actor_class.new{|msg| @expected = msg }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        actor << true
        @thread.join(0.1)
        @expected.should be_true
        actor.stop
      end
    end

    context '#post!' do

      it 'returns an Obligation' do
        actor = actor_class.new
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        obligation = actor.post!(nil)
        obligation.should be_a(Obligation)
        actor.stop
      end

      it 'fulfills the obligation on success' do
        actor = actor_class.new{|msg| @expected = msg }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        obligation = actor.post!(42)
        @thread.join(0.1)
        obligation.should be_fulfilled
        obligation.value.should == 42
        actor.stop
      end

      it 'rejects the obligation on failure' do
        actor = actor_class.new{|msg| raise StandardError.new('Boom!') }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        obligation = actor.post!(42)
        @thread.join(0.1)
        obligation.should be_rejected
        obligation.reason.should be_a(StandardError)
        actor.stop
      end
    end

    context '#post?' do

      it 'blocks for up to the given number of seconds' do
        actor = actor_class.new{|msg| sleep }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        start = Time.now.to_i
        expect {
          actor.post?(2, nil)
        }.to raise_error
        elapsed = Time.now.to_i - start
        elapsed.should >= 2
        actor.stop
      end

      it 'raises Concurrent::TimeoutError when seconds is zero' do
        actor = actor_class.new{|msg| 42 }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        expect {
          actor.post?(0, nil)
        }.to raise_error(Concurrent::TimeoutError)
        actor.stop
      end

      it 'raises Concurrent::TimeoutError on timeout' do
        actor = actor_class.new{|msg| sleep }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        expect {
          actor.post?(1, nil)
        }.to raise_error(Concurrent::TimeoutError)
        actor.stop
      end

      it 'bubbles the exception on error' do
        actor = actor_class.new{|msg| raise StandardError.new('Boom!') }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        expect {
          actor.post?(1, nil)
        }.to raise_error(StandardError)
        actor.stop
      end

      it 'returns the result on success' do
        actor = actor_class.new{|msg| 42 }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        expected = actor.post?(1, nil)
        expected.should == 42
        actor.stop
      end

      it 'attempts to cancel the operation on timeout' do
        @expected = 0
        actor = actor_class.new{|msg| sleep(0.5); @expected += 1 }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        actor.post(nil) # block the actor
        expect {
          actor.post?(0.1, nil)
        }.to raise_error(Concurrent::TimeoutError)
        sleep(1.5)
        @expected.should == 1
        actor.stop
      end
    end

    context '#forward' do

      let(:sender_clazz) do
        Class.new(Actor) do
          def act(*message)
            if message.first.is_a?(Exception)
              raise message.first
            else
              return message.first
            end
          end
        end
      end

      let(:receiver_clazz) do
        Class.new(Actor) do
          attr_reader :result
          def act(*message)
            @result = message.first
          end
        end
      end

      let(:sender) { sender_clazz.new }
      let(:receiver) { receiver_clazz.new }

      let(:observer) { double('observer') }

      before(:each) do
        @sender = Thread.new{ sender.run }
        @receiver = Thread.new{ receiver.run }
        sleep(0.1)
      end

      after(:each) do
        sender.stop
        receiver.stop
        sleep(0.1)
        @sender.kill unless @sender.nil?
        @receiver.kill unless @receiver.nil?
      end

      it 'forwards the result to the receiver on success' do
        sender.forward(receiver, 42)
        sleep(0.1)
        receiver.result.should eq 42
      end

      it 'does not forward on exception' do
        sender.forward(receiver, StandardError.new)
        sleep(0.1)
        receiver.result.should be_nil
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

    context '#run' do

      it 'empties the queue' do
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        q = subject.instance_variable_get(:@queue)
        q.size.should == 0
      end
    end

    context '#stop' do

      it 'empties the queue' do
        actor = actor_class.new{|msg| sleep }
        @thread = Thread.new{ actor.run }
        10.times { actor.post(true) }
        @thread.join(0.1)
        actor.stop
        @thread.join(0.1)
        q = actor.instance_variable_get(:@queue)
        if q.size >= 1
          q.pop.should == :stop
        else
          q.size.should == 0
        end
      end

      it 'pushes a :stop message onto the queue' do
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        q = subject.instance_variable_get(:@queue)
        q.should_receive(:push).once.with(:stop)
        subject.stop
        @thread.join(0.1)
      end
    end

    context 'exception handling' do

      it 'supresses exceptions thrown when handling messages' do
        actor = actor_class.new{|msg| raise StandardError }
        @thread = Thread.new{ actor.run }
        expect {
          @thread.join(0.1)
          10.times { actor.post(true) }
        }.not_to raise_error
        actor.stop
      end
    end

    context 'observation' do

      let(:actor_class) do
        Class.new(Actor) do
          def act(*message)
            if message.first.is_a?(Exception)
              raise message.first
            else
              return message.first
            end
          end
        end
      end

      subject { Class.new(actor_class).new }

      let(:observer) do
        Class.new {
          attr_reader :time
          attr_reader :message
          attr_reader :value
          attr_reader :reason
          def update(time, message, value, reason)
            @time = time
            @message = message
            @value = value
            @reason = reason
          end
        }.new
      end

      it 'notifies observers when a message is successfully handled' do
        observer.should_receive(:update).exactly(10).times.with(any_args())
        subject.add_observer(observer)
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        10.times { subject.post(42) }
        @thread.join(0.1)
      end

      it 'notifies observers when a message raises an exception' do
        error = StandardError.new
        observer.should_receive(:update).exactly(10).times.with(any_args())
        subject.add_observer(observer)
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        10.times { subject.post(error) }
        @thread.join(0.1)
      end

      it 'passes the time, message, value, and reason to the observer on success' do
        subject.add_observer(observer)
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        subject.post(42)
        @thread.join(0.1)

        observer.time.should be_a(Time)
        observer.message.should eq [42]
        observer.value.should eq 42
        observer.reason.should be_nil
      end

      it 'passes the time, message, value, and reason to the observer on exception' do
        error = StandardError.new
        subject.add_observer(observer)
        @thread = Thread.new{ subject.run }
        @thread.join(0.1)
        subject.post(error)
        @thread.join(0.1)

        observer.time.should be_a(Time)
        observer.message.should eq [error]
        observer.value.should be_nil
        observer.reason.should be_a(Exception)
      end
    end

    context '#pool' do

      let(:clazz){ Class.new(actor_class) }

      it 'raises an exception if the count is zero or less' do
        expect {
          clazz.pool(0)
        }.to raise_error(ArgumentError)
      end

      it 'creates the requested number of actors' do
        mailbox, actors = clazz.pool(5)
        actors.size.should == 5
      end

      it 'passes the block to each actor' do
        block = proc{ nil }
        clazz.should_receive(:new).with(&block)
        clazz.pool(1, &block)
      end

      it 'gives all actors the same mailbox' do
        mailbox, actors = clazz.pool(2)
        mbox1 = actors.first.instance_variable_get(:@queue)
        mbox2 = actors.last.instance_variable_get(:@queue)
        mbox1.should eq mbox2
      end

      it 'returns a Poolbox as the first retval' do
        mailbox, actors = clazz.pool(2)
        mailbox.should be_a(Actor::Poolbox)
      end

      it 'gives the Poolbox the same mailbox as the actors' do
        mailbox, actors = clazz.pool(1)
        mbox1 = mailbox.instance_variable_get(:@queue)
        mbox2 = actors.first.instance_variable_get(:@queue)
        mbox1.should eq mbox2
      end

      it 'returns an array of actors as the second retval' do
        mailbox, actors = clazz.pool(2)
        actors.each do |actor|
          actor.should be_a(clazz)
        end
      end

      it 'posts to the mailbox with Poolbox#post' do
        @expected = false
        mailbox, actors = clazz.pool(1){|msg| @expected = true }
        @thread = Thread.new{ actors.first.run }
        sleep(0.1)
        mailbox.post(42)
        sleep(0.1)
        actors.each{|actor| actor.stop }
        @thread.kill
        @expected.should be_true
      end

      it 'posts to the mailbox with Poolbox#<<' do
        @expected = false
        mailbox, actors = clazz.pool(1){|msg| @expected = true }
        @thread = Thread.new{ actors.first.run }
        sleep(0.1)
        mailbox << 42
        sleep(0.1)
        actors.each{|actor| actor.stop }
        @thread.kill
        @expected.should be_true
      end
    end

    context 'subclassing' do

      after(:each) do
        @thread.kill unless @thread.nil?
      end

      context '#pool' do

        it 'creates actors of the appropriate subclass' do
          actor = Class.new(actor_class)
          mailbox, actors = actor.pool(1)
          actors.first.should be_a(actor)
        end
      end

      context '#act overloading' do

        it 'raises an exception if #act is not implemented in the subclass' do
          actor = Class.new(Actor).new
          @thread = Thread.new{ actor.run }
          @thread.join(0.1)
          expect {
            actor.post(:foo)
            @thread.join(0.1)
          }.to raise_error(NotImplementedError)
          actor.stop
        end

        it 'uses the subclass #act implementation' do
          actor = actor_class.new{|*args| @expected = true }
          @thread = Thread.new{ actor.run }
          @thread.join(0.1)
          actor.post(:foo)
          @thread.join(0.1)
          actor.last_message.should eq [:foo]
          actor.stop
        end
      end

      context '#on_error overloading' do

        let(:bad_actor) do
          Class.new(actor_class) {
            attr_reader :last_error
            def act(*message)
              raise StandardError
            end
            def on_error(*args)
              @last_error = args
            end
          }
        end

        it 'uses the subclass #on_error implementation' do
          actor = bad_actor.new
          @thread = Thread.new{ actor.run }
          @thread.join(0.1)
          actor.post(42)
          @thread.join(0.1)
          actor.last_error[0].should be_a(Time)
          actor.last_error[1].should eq [42]
          actor.last_error[2].should be_a(StandardError)
          actor.stop
        end
      end
    end

    context 'supervision' do

      it 'can be started by a Supervisor' do
        actor = actor_class.new
        supervisor = Supervisor.new
        supervisor.add_worker(actor)

        actor.should_receive(:run).with(no_args())
        supervisor.run!
        sleep(0.1)

        supervisor.stop
        sleep(0.1)
        actor.stop
      end

      it 'can receive messages while under supervision' do
        @expected = false
        actor = actor_class.new{|*args| @expected = true}
        supervisor = Supervisor.new
        supervisor.add_worker(actor)
        supervisor.run!
        sleep(0.1)

        actor.post(42)
        sleep(0.1)
        @expected.should be_true

        supervisor.stop
        sleep(0.1)
        actor.stop
      end

      it 'can be stopped by a supervisor' do
        actor = actor_class.new
        supervisor = Supervisor.new
        supervisor.add_worker(actor)

        supervisor.run!
        sleep(0.1)

        actor.should_receive(:stop).with(no_args())
        supervisor.stop
        sleep(0.1)
      end
    end
  end
end

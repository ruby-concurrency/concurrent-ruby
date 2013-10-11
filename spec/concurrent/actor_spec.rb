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

    context 'message handling' do

      it 'runs the constructor block once for every message' do
        @expected = 0
        actor = actor_class.new{|msg| @expected += 1 }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        10.times { actor.post(true) }
        @thread.join(0.1)
        @expected.should eq 10
        actor.stop
      end

      it 'passes the message to the block' do
        @expected = []
        actor = actor_class.new{|msg| @expected << msg }
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        10.times {|i| actor.post(i) }
        @thread.join(0.1)
        actor.stop
        @expected.should eq (0..9).to_a
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
        @thread.join(0.1)
        10.times { subject.post(true) }
        @thread.join(0.1)
      end

      it 'does not notify observers when a message raises an exception' do
        observer.should_not_receive(:update).with(any_args())
        actor = actor_class.new{|msg| raise StandardError }
        actor.add_observer(observer)
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        10.times { actor.post(true) }
        @thread.join(0.1)
        actor.stop
      end

      it 'passes the time, message, and result to the observer' do
        actor = actor_class.new{|*msg| msg }
        actor.add_observer(observer)
        @thread = Thread.new{ actor.run }
        @thread.join(0.1)
        actor.post(42)
        @thread.join(0.1)
        observer.notice[0].should be_a(Time)
        observer.notice[1].should == [42]
        observer.notice[2].should == [42]
        actor.stop
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

require 'spec_helper'
require_relative 'postable_shared'
require_relative '../runnable_shared'

module Concurrent

  describe Actor do

    before do
      # suppress deprecation warnings.
      Concurrent::Actor.any_instance.stub(:warn)
      Concurrent::Actor.stub(:warn)
    end

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

    ## :runnable
    subject { Class.new(actor_class).new }
    it_should_behave_like :runnable

    ## :postable

    let!(:postable_class){ actor_class }

    let(:sender_class) do
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

    let(:sender) { sender_class.new }
    let(:receiver) { postable_class.new }

    it_should_behave_like :postable

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

      #it 'supresses exceptions thrown when handling messages' do
        #pending('intermittently failing; deprecated')
        #actor = actor_class.new{|msg| raise StandardError }
        #@thread = Thread.new{ actor.run }
        #expect {
          #@thread.join(0.1)
          #10.times { actor.post(true) }
        #}.not_to raise_error
        #actor.stop
      #end
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

      #it 'notifies observers when a message is successfully handled' do
        #pending('intermittently failing; deprecated')
        #observer.should_receive(:update).exactly(10).times.with(any_args())
        #subject.add_observer(observer)
        #@thread = Thread.new{ subject.run }
        #@thread.join(0.1)
        #10.times { subject.post(42) }
        #@thread.join(0.1)
      #end

      #it 'notifies observers when a message raises an exception' do
        #pending('intermittently failing; deprecated')
        #error = StandardError.new
        #observer.should_receive(:update).exactly(10).times.with(any_args())
        #subject.add_observer(observer)
        #@thread = Thread.new{ subject.run }
        #@thread.join(0.1)
        #10.times { subject.post(error) }
        #@thread.join(0.1)
      #end

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

      it 'creates the requested number of pool' do
        mailbox, pool = clazz.pool(5)
        pool.size.should == 5
      end

      it 'passes all optional arguments to the individual constructors' do
        clazz.should_receive(:new).with(1, 2, 3).exactly(5).times
        clazz.pool(5, 1, 2, 3)
      end

      it 'passes a duplicate of the given block to each actor in the pool' do
        block = proc{ nil }
        block.should_receive(:dup).exactly(5).times.and_return(proc{ nil })
        mailbox, pool = clazz.pool(5, &block)
      end

      it 'gives all pool the same mailbox' do
        mailbox, pool = clazz.pool(2)
        mbox1 = pool.first.instance_variable_get(:@queue)
        mbox2 = pool.last.instance_variable_get(:@queue)
        mbox1.should eq mbox2
      end

      it 'returns a Poolbox as the first retval' do
        mailbox, pool = clazz.pool(2)
        mailbox.should be_a(Actor::Poolbox)
      end

      it 'gives the Poolbox the same mailbox as the pool' do
        mailbox, pool = clazz.pool(1)
        mbox1 = mailbox.instance_variable_get(:@queue)
        mbox2 = pool.first.instance_variable_get(:@queue)
        mbox1.should eq mbox2
      end

      it 'returns an array of pool as the second retval' do
        mailbox, pool = clazz.pool(2)
        pool.each do |actor|
          actor.should be_a(clazz)
        end
      end

      it 'posts to the mailbox with Poolbox#post' do
        mailbox, pool = clazz.pool(1)
        @thread = Thread.new{ pool.first.run }
        sleep(0.1)
        mailbox.post(42)
        sleep(0.1)
        pool.first.last_message.should eq [42]
        pool.first.stop
        @thread.kill
      end

      #it 'posts to the mailbox with Poolbox#<<' do
        #pending('intermittently failing; deprecated')
        #@expected = false
        #mailbox, pool = clazz.pool(1)
        #@thread = Thread.new{ pool.first.run }
        #sleep(0.1)
        #mailbox << 42
        #sleep(0.1)
        #pool.first.last_message.should eq [42]
        #pool.first.stop
        #@thread.kill
      #end
    end

    context 'subclassing' do

      after(:each) do
        @thread.kill unless @thread.nil?
      end

      context '#pool' do

        it 'creates pool of the appropriate subclass' do
          actor = Class.new(actor_class)
          mailbox, pool = actor.pool(1)
          pool.first.should be_a(actor)
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

require 'spec_helper'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe Agent do

    let!(:thread_pool_user){ Agent }
    it_should_behave_like Concurrent::UsesGlobalThreadPool

    subject { Agent.new(0) }

    let(:observer) do
      Class.new do
        attr_reader :value
        define_method(:update) do |time, value|
          @value = value
        end
      end.new
    end

    before(:each) do
      Agent.thread_pool = FixedThreadPool.new(1)
    end

    it 'includes Dereferenceable' do
      agent = Agent.new(10)
      agent.should be_a(Dereferenceable)
    end

    context '#initialize' do

      it 'sets the value to the given initial state' do
        Agent.new(10).value.should eq 10
      end

      it 'sets the timeout to the given value' do
        Agent.new(0, timeout: 5).timeout.should eq 5
      end

      it 'sets the timeout to the default when nil' do
        Agent.new(0).timeout.should eq Agent::TIMEOUT
      end
    end

    context '#rescue' do

      it 'returns self when a block is given' do
        a1 = subject
        a2 = a1.rescue{}
        a1.object_id.should eq a2.object_id
      end

      it 'returns self when no block is given' do
        a1 = subject
        a2 = a1.rescue
        a1.object_id.should eq a2.object_id
      end

      it 'accepts an exception class as the first parameter' do
        lambda {
          subject.rescue(StandardError){}
        }.should_not raise_error
      end

      it 'ignores rescuers without a block' do
        subject.rescue
        subject.instance_variable_get(:@rescuers).should be_empty
      end
    end

    context '#validate' do

      it 'returns self when a block is given' do
        a1 = subject
        a2 = a1.validate{}
        a1.object_id.should eq a2.object_id
      end

      it 'returns self when no block is given' do
        a1 = subject
        a2 = a1.validate
        a1.object_id.should eq a2.object_id
      end

      it 'ignores validators without a block' do
        subject.validate
        subject.instance_variable_get(:@validator).should be_nil
      end
    end

    context '#post' do
      
      it 'adds the given block to the queue' do
        Agent.thread_pool.should_receive(:post).with(no_args()).exactly(3).times
        subject.post{ sleep(100) }
        subject.post{ nil }
        subject.post{ nil }
        sleep(0.1)
      end

      it 'does not add to the queue when no block is given' do
        Agent.thread_pool.should_receive(:post).with(no_args()).exactly(2).times
        subject.post{ sleep(100) }
        subject.post
        subject.post{ nil }
        sleep(0.1)
      end
    end

    context 'fulfillment' do

      it 'process each block in the queue' do
        @expected = []
        subject.post{ @expected << 1 }
        subject.post{ @expected << 2 }
        subject.post{ @expected << 3 }
        sleep(0.1)
        @expected.should eq [1,2,3]
      end

      it 'passes the current value to the handler' do
        @expected = nil
        Agent.new(10).post{|i| @expected = i }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'sets the value to the handler return value on success' do
        subject.post{ 100 }
        sleep(0.1)
        subject.value.should eq 100
      end

      it 'rejects the handler after timeout reached' do
        agent = Agent.new(0, timeout: 0.1)
        agent.post{ sleep(1); 10 }
        agent.value.should eq 0
      end
    end

    context 'validation' do

      it 'processes the validator when present' do
        @expected = nil
        subject.validate{ @expected = 10; true }
        subject.post{ nil }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'passes the new value to the validator' do
        @expected = nil
        subject.validate{|v| @expected = v; true }
        subject.post{ 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'sets the new value when the validator returns true' do
        agent = Agent.new(0).validate{ true }
        agent.post{ 10 }
        sleep(0.1)
        agent.value.should eq 10
      end

      it 'does not change the value when the validator returns false' do
        agent = Agent.new(0).validate{ false }
        agent.post{ 10 }
        sleep(0.1)
        agent.value.should eq 0
      end

      it 'does not change the value when the validator raises an exception' do
        agent = Agent.new(0).validate{ raise StandardError }
        agent.post{ 10 }
        sleep(0.1)
        agent.value.should eq 0
      end
    end

    context 'rejection' do

      it 'calls the first exception block with a matching class' do
        @expected = nil
        subject.
          rescue(StandardError){|ex| @expected = 1 }.
          rescue(StandardError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }
        subject.post{ raise StandardError }
          sleep(0.1)
        @expected.should eq 1
      end

      it 'matches all with a rescue with no class given' do
        @expected = nil
        subject.
          rescue(LoadError){|ex| @expected = 1 }.
          rescue{|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }
        subject.post{ raise NoMethodError }
        sleep(0.1)
        @expected.should eq 2
      end

      it 'searches associated rescue handlers in order' do
        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }
        subject.post{ raise ArgumentError }
        sleep(0.1)
        @expected.should eq 1

        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }
        subject.post{ raise LoadError }
        sleep(0.1)
        @expected.should eq 2

        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should eq 3
      end

      it 'passes the exception object to the matched block' do
        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = ex }.
          rescue(LoadError){|ex| @expected = ex }.
          rescue(StandardError){|ex| @expected = ex }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'ignores rescuers without a block' do
        @expected = nil
        subject.
          rescue(StandardError).
          rescue(StandardError){|ex| @expected = ex }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'supresses the exception if no rescue matches' do
        lambda {
          subject.
            rescue(ArgumentError){|ex| @expected = ex }.
            rescue(NotImplementedError){|ex| @expected = ex }.
            rescue(NoMethodError){|ex| @expected = ex }
          subject.post{ raise StandardError }
          sleep(0.1)
        }.should_not raise_error
      end

      it 'supresses exceptions thrown from rescue handlers' do
        lambda {
          subject.rescue(StandardError){ raise StandardError }
          subject.post{ raise ArgumentError }
          sleep(0.1)
        }.should_not raise_error
      end
    end

    context 'Dereferenceable' do

      it 'defaults :dup_on_deref to false' do
        value = 'value'
        value.should_not_receive(:dup).with(any_args())

        agent = Agent.new(value)
        agent.value.should eq 'value'

        agent = Agent.new(value, dup_on_deref: false)
        agent.value.should eq 'value'

        agent = Agent.new(value, dup: false)
        agent.value.should eq 'value'
      end

      it 'calls #dup when the :dup_on_deref option is true' do
        value = 'value'
        
        agent = Agent.new(value, dup_on_deref: true)
        agent.value.object_id.should_not eq value.object_id
        agent.value.should eq 'value'

        agent = Agent.new(value, dup: true)
        agent.value.object_id.should_not eq value.object_id
        agent.value.should eq 'value'
      end

      it 'defaults :freeze_on_deref to false' do
        value = 'value'
        value.should_not_receive(:freeze).with(any_args())

        agent = Agent.new(value)
        agent.value.should eq 'value'

        agent = Agent.new(value, freeze_on_deref: false)
        agent.value.should eq 'value'

        agent = Agent.new(value, freeze: false)
        agent.value.should eq 'value'
      end

      it 'calls #freeze when the :freeze_on_deref option is true' do
        value = 'value'

        agent = Agent.new(value, freeze_on_deref: true)
        agent.value.should be_frozen
        agent.value.should eq 'value'

        agent = Agent.new(value, freeze: true)
        agent.value.should be_frozen
        agent.value.should eq 'value'
      end

      it 'defaults :copy_on_deref to nil' do
        value = 'value'

        agent = Agent.new(value)
        agent.value.object_id.should == value.object_id
        agent.value.should eq 'value'

        agent = Agent.new(value, copy_on_deref: nil)
        agent.value.object_id.should == value.object_id
        agent.value.should eq 'value'

        agent = Agent.new(value, copy: nil)
        agent.value.object_id.should == value.object_id
        agent.value.should eq 'value'
      end

      it 'calls the block when the :copy_on_deref option is passed a proc' do
        value = 'value'
        copy = proc{|val| 'copy' }

        agent = Agent.new(value, copy_on_deref: copy)
        agent.value.object_id.should_not == value.object_id

        agent = Agent.new(value, copy: copy)
        agent.value.object_id.should_not == value.object_id
      end

      it 'calls the :copy block first followed by #dup followed by #freeze' do
        value = 'value'
        copied = 'copied'
        dup = 'dup'
        frozen = 'frozen'
        copy = proc{|val| copied }

        copied.should_receive(:dup).with(no_args()).and_return(dup)
        dup.should_receive(:freeze).with(no_args()).and_return(frozen)

        agent = Agent.new(value, dup_on_deref: true, freeze_on_deref: true, copy_on_deref: copy)
        agent.value.should eq frozen
      end

      it 'does not call #dup when #dup_on_deref is set and the value is nil' do
        allow_message_expectations_on_nil
        result = nil
        result.should_not_receive(:dup).with(any_args())
        agent = Agent.new(result, dup_on_deref: true)
        agent.value
      end

      it 'does not call #freeze when #freeze_on_deref is set and the value is nil' do
        allow_message_expectations_on_nil
        result = nil
        result.should_not_receive(:freeze).with(any_args())
        agent = Agent.new(result, freeze_on_deref: true)
        agent.value
      end

      it 'does not call the #copy_on_deref block when the value is nil' do
        copier = proc { 42 }
        agent = Agent.new(nil, copy_on_deref: copier)
        agent.value.should be_nil
      end

      it 'does not lock when all options are false' do
        agent = Agent.new(0)
        mutex = double('mutex')
        agent.stub(:mutex).and_return(mutex)
        mutex.should_not_receive(:synchronize)
        agent.value
      end

      it 'supports dereference flags with observers' do
        result = 'result'
        result.should_receive(:dup).and_return(result)
        result.should_receive(:freeze).and_return(result)
        copier = proc { result }

        observer = double('observer')
        observer.should_receive(:update).with(any_args())

        agent = Agent.new(nil, dup_on_deref: true, freeze_on_deref: true, copy_on_deref: copier)
        agent.add_observer(observer)

        agent << proc { 'original result' }
        sleep(0.1)
      end
    end

    context 'observation' do

      it 'notifies all observers when the value changes' do
        agent = Agent.new(0)
        agent.add_observer(observer)
        agent.post{ 10 }
        sleep(0.1)
        observer.value.should eq 10
      end

      it 'does not notify observers when validation fails' do
        agent = Agent.new(0)
        agent.validate{ false }
        agent.add_observer(observer)
        agent.post{ 10 }
        sleep(0.1)
        observer.value.should be_nil
      end

      it 'does not notify observers when the handler raises an exception' do
        agent = Agent.new(0)
        agent.add_observer(observer)
        agent.post{ raise StandardError }
        sleep(0.1)
        observer.value.should be_nil
      end
    end

    context 'aliases' do

      it 'aliases #deref for #value' do
        Agent.new(10).deref.should eq 10
      end

      it 'aliases #validates for :validate' do
        @expected = nil
        subject.validates{|v| @expected = v }
        subject.post{ 10 }
        sleep(0.1)
        @expected.should eq 10
      end
        
      it 'aliases #validate_with for :validate' do
        @expected = nil
        subject.validate_with{|v| @expected = v }
        subject.post{ 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'aliases #validates_with for :validate' do
        @expected = nil
        subject.validates_with{|v| @expected = v }
        subject.post{ 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'aliases #catch for #rescue' do
        @expected = nil
        subject.catch{ @expected = true }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_true
      end

      it 'aliases #on_error for #rescue' do
        @expected = nil
        subject.on_error{ @expected = true }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_true
      end

      it 'aliases #add_watch for #add_observer' do
        agent = Agent.new(0)
        agent.add_watch(observer)
        agent.post{ 10 }
        sleep(0.1)
        observer.value.should eq 10
      end
    end

    context 'stress test' do

      before(:each) do
        Agent.thread_pool = FixedThreadPool.new(5)
      end

      specify do
        count = 10_000
        counter = Concurrent::Agent.new(0)

        count.times do |i|
          counter.post{|value| value + 1 }
        end

        sleep(0.1) until counter.value == count
      end
    end
  end
end

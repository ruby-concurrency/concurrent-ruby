require 'spec_helper'

module Concurrent

  describe Agent do

    subject { Agent.new(0) }

    let(:observer) do
      Class.new do
        attr_reader :value
        define_method(:update) do |time, value|
          @value = value
        end
      end.new
    end

    context '#initialize' do

      it 'sets the value to the given initial state' do
        Agent.new(10).value.should eq 10
      end

      it 'sets the timeout to the given value' do
        Agent.new(0, 5).timeout.should eq 5
      end

      it 'sets the timeout to the default when nil' do
        Agent.new(0).timeout.should eq Agent::TIMEOUT
      end

      it 'sets the length to zero' do
        Agent.new(10).length.should eq 0
      end

      it 'spawns the worker thread' do
        Thread.should_receive(:new).once.with(any_args())
        Agent.new(0)
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
        before = subject.length
        subject.post{ nil }
        subject.post{ nil }
        subject.length.should eq before+2
      end

      it 'does not add to the queue when no block is given' do
        before = subject.length
        subject.post
        subject.post{ nil }
        subject.length.should eq before+1
      end
    end

    context '#length' do

      it 'should be zero for a new agent' do
        subject.length.should eq 0
      end

      it 'should increase by one for each #post' do
        subject.post{ sleep }
        subject.post{ sleep }
        subject.post{ sleep }
        subject.length.should eq 3
      end

      it 'should decrease by one each time a handler is run' do
        subject.post{ nil }
        subject.post{ sleep }
        subject.post{ sleep }
        sleep(0.1)
        subject.length.should eq 1
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
        agent = Agent.new(0, 0.1)
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
          rescue(Exception){|ex| @expected = 3 }
        subject.post{ raise ArgumentError }
        sleep(0.1)
        @expected.should eq 1

        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(Exception){|ex| @expected = 3 }
        subject.post{ raise LoadError }
        sleep(0.1)
        @expected.should eq 2

        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(Exception){|ex| @expected = 3 }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should eq 3
      end

      it 'passes the exception object to the matched block' do
        @expected = nil
        subject.
          rescue(ArgumentError){|ex| @expected = ex }.
          rescue(LoadError){|ex| @expected = ex }.
          rescue(Exception){|ex| @expected = ex }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'ignores rescuers without a block' do
        @expected = nil
        subject.
          rescue(StandardError).
          rescue(StandardError){|ex| @expected = ex }.
          rescue(Exception){|ex| @expected = ex }
        subject.post{ raise StandardError }
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'supresses the exception if no rescue matches' do
        lambda {
          subject.
            rescue(ArgumentError){|ex| @expected = ex }.
            rescue(StandardError){|ex| @expected = ex }.
            rescue(Exception){|ex| @expected = ex }
          subject.post{ raise StandardError }
          sleep(0.1)
        }.should_not raise_error
      end

      it 'supresses exceptions thrown from rescue handlers' do
        lambda {
          subject.rescue(Exception){ raise StandardError }
          subject.post{ raise ArgumentError }
          sleep(0.1)
        }.should_not raise_error
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
  end
end

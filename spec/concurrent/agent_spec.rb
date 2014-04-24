require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'observable_shared'

module Concurrent

  describe Agent do

    let(:executor) { PerThreadExecutor.new }

    subject { Agent.new(0, executor: executor) }

    let(:observer) do
      Class.new do
        attr_reader :value
        define_method(:update) do |time, value|
          @value = value
        end
      end.new
    end

    context 'behavior' do

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        opts = opts.merge(executor: executor)
        Agent.new(value, opts)
      end

      def dereferenceable_observable(opts = {})
        opts = opts.merge(executor: executor)
        Agent.new(0, opts)
      end

      def execute_dereferenceable(subject)
        subject.post{|value| 10 }
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable

      # observable
      
      subject{ Agent.new(0) }
      
      def trigger_observable(observable)
        observable.post{ nil }
        sleep(0.1)
      end

      it_should_behave_like :observable
    end

    context '#initialize' do

      let(:executor) { ImmediateExecutor.new }

      it 'sets the value to the given initial state' do
        Agent.new(10).value.should eq 10
      end

      it 'sets the timeout to the given value' do
        Agent.new(0, timeout: 5).timeout.should eq 5
      end

      it 'sets the timeout to the default when nil' do
        Agent.new(0).timeout.should eq Agent::TIMEOUT
      end

      it 'uses the executor given with the :executor option' do
        executor.should_receive(:post).with(any_args).and_return(0)
        agent = Agent.new(0, executor: executor)
        agent.post{|value| 0 }
      end

      it 'uses the global operation pool when :operation is true' do
        Concurrent.configuration.should_receive(:global_operation_pool).and_return(executor)
        agent = Agent.new(0, operation: true)
        agent.post{|value| 0 }
      end

      it 'uses the global task pool when :task is true' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        agent = Agent.new(0, task: true)
        agent.post{|value| 0 }
      end

      it 'uses the global task pool by default' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        agent = Agent.new(0)
        agent.post{|value| 0 }
      end
    end

    context '#rescue' do

      it 'returns self when a block is given' do
        a1 = subject
        a2 = a1.rescue {}

        a2.should be a1
      end

      it 'returns self when no block is given' do
        a1 = subject
        a2 = a1.rescue

        a2.should be a1
      end

      it 'accepts an exception class as the first parameter' do
        lambda {
          subject.rescue(StandardError) {}
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
        a2 = a1.validate {}

        a2.should be a1
      end

      it 'returns self when no block is given' do
        a1 = subject
        a2 = a1.validate

        a2.should be a1
      end

      it 'ignores validators without a block' do
        default_validator = subject.instance_variable_get(:@validator)
        subject.validate
        subject.instance_variable_get(:@validator).should be default_validator
      end
    end

    context '#post' do

      it 'adds the given block to the queue' do
        executor.should_receive(:post).with(no_args).exactly(3).times
        subject.post { sleep(100) }
        subject.post { nil }
        subject.post { nil }
        sleep(0.1)
      end

      it 'does not add to the queue when no block is given' do
        executor.should_receive(:post).with(no_args).exactly(2).times
        subject.post { sleep(100) }
        subject.post
        subject.post { nil }
        sleep(0.1)
      end
    end

    context 'fulfillment' do

      it 'process each block in the queue' do
        @expected = []
        subject.post { @expected << 1 }
        subject.post { @expected << 2 }
        subject.post { @expected << 3 }
        sleep(0.1)
        @expected.sort.should eq [1, 2, 3]
      end

      it 'passes the current value to the handler' do
        @expected = nil
        Agent.new(10, executor: executor).post { |i| @expected = i }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'sets the value to the handler return value on success' do
        subject.post { 100 }
        sleep(0.1)
        subject.value.should eq 100
      end

      it 'rejects the handler after timeout reached' do
        agent = Agent.new(0, timeout: 0.1, executor: executor)
        agent.post { sleep(1); 10 }
        agent.value.should eq 0
      end
    end

    context 'validation' do

      it 'processes the validator when present' do
        @expected = nil
        subject.validate { @expected = 10; true }
        subject.post { nil }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'passes the new value to the validator' do
        @expected = nil
        subject.validate { |v| @expected = v; true }
        subject.post { 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'sets the new value when the validator returns true' do
        agent = Agent.new(0, executor: executor).validate { true }
        agent.post { 10 }
        sleep(0.1)
        agent.value.should eq 10
      end

      it 'does not change the value when the validator returns false' do
        agent = Agent.new(0, executor: executor).validate { false }
        agent.post { 10 }
        sleep(0.1)
        agent.value.should eq 0
      end

      it 'does not change the value when the validator raises an exception' do
        agent = Agent.new(0, executor: executor).validate { raise StandardError }
        agent.post { 10 }
        sleep(0.1)
        agent.value.should eq 0
      end
    end

    context 'rejection' do

      it 'calls the first exception block with a matching class' do
        @expected = nil
        subject.
      rescue(StandardError) { |ex| @expected = 1 }.
        rescue(StandardError) { |ex| @expected = 2 }.
        rescue(StandardError) { |ex| @expected = 3 }
          subject.post { raise StandardError }
          sleep(0.1)
          @expected.should eq 1
        end

      it 'matches all with a rescue with no class given' do
        @expected = nil
        subject.
      rescue(LoadError) { |ex| @expected = 1 }.
        rescue { |ex| @expected = 2 }.
        rescue(StandardError) { |ex| @expected = 3 }
          subject.post { raise NoMethodError }
          sleep(0.1)
          @expected.should eq 2
        end

      it 'searches associated rescue handlers in order' do
        @expected = nil
        subject.
      rescue(ArgumentError) { |ex| @expected = 1 }.
        rescue(LoadError) { |ex| @expected = 2 }.
        rescue(StandardError) { |ex| @expected = 3 }
          subject.post { raise ArgumentError }
          sleep(0.1)
          @expected.should eq 1

          @expected = nil
          subject.
        rescue(ArgumentError) { |ex| @expected = 1 }.
          rescue(LoadError) { |ex| @expected = 2 }.
          rescue(StandardError) { |ex| @expected = 3 }
            subject.post { raise LoadError }
            sleep(0.1)
            @expected.should eq 2

            @expected = nil
            subject.
          rescue(ArgumentError) { |ex| @expected = 1 }.
            rescue(LoadError) { |ex| @expected = 2 }.
            rescue(StandardError) { |ex| @expected = 3 }
              subject.post { raise StandardError }
              sleep(0.1)
              @expected.should eq 3
            end

      it 'passes the exception object to the matched block' do
        @expected = nil
        subject.
      rescue(ArgumentError) { |ex| @expected = ex }.
        rescue(LoadError) { |ex| @expected = ex }.
        rescue(StandardError) { |ex| @expected = ex }
          subject.post { raise StandardError }
          sleep(0.1)
          @expected.should be_a(StandardError)
        end

      it 'ignores rescuers without a block' do
        @expected = nil
        subject.
      rescue(StandardError).
        rescue(StandardError) { |ex| @expected = ex }
          subject.post { raise StandardError }
          sleep(0.1)
          @expected.should be_a(StandardError)
        end

      it 'supresses the exception if no rescue matches' do
        lambda {
          subject.
      rescue(ArgumentError) { |ex| @expected = ex }.
        rescue(NotImplementedError) { |ex| @expected = ex }.
        rescue(NoMethodError) { |ex| @expected = ex }
          subject.post { raise StandardError }
          sleep(0.1)
        }.should_not raise_error
        end

      it 'suppresses exceptions thrown from rescue handlers' do
        lambda {
          subject.rescue(StandardError) { raise StandardError }
          subject.post { raise ArgumentError }
          sleep(0.1)
        }.should_not raise_error
      end
    end

    context 'observation' do

      it 'notifies all observers when the value changes' do
        agent = Agent.new(0, executor: executor)
        agent.add_observer(observer)
        agent.post { 10 }
        sleep(0.1)
        observer.value.should eq 10
      end

      it 'does not notify removed observers when the value changes' do
        agent = Agent.new(0, executor: executor)
        agent.add_observer(observer)
        agent.delete_observer(observer)
        agent.post { 10 }
        sleep(0.1)
        observer.value.should be_nil
      end

      it 'does not notify observers when validation fails' do
        agent = Agent.new(0, executor: executor)
        agent.validate { false }
        agent.add_observer(observer)
        agent.post { 10 }
        sleep(0.1)
        observer.value.should be_nil
      end

      it 'does not notify observers when the handler raises an exception' do
        agent = Agent.new(0, executor: executor)
        agent.add_observer(observer)
        agent.post { raise StandardError }
        sleep(0.1)
        observer.value.should be_nil
      end
    end

    context 'aliases' do

      it 'aliases #deref for #value' do
        Agent.new(10, executor: executor).deref.should eq 10
      end

      it 'aliases #validates for :validate' do
        @expected = nil
        subject.validates { |v| @expected = v }
        subject.post { 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'aliases #validate_with for :validate' do
        @expected = nil
        subject.validate_with { |v| @expected = v }
        subject.post { 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'aliases #validates_with for :validate' do
        @expected = nil
        subject.validates_with { |v| @expected = v }
        subject.post { 10 }
        sleep(0.1)
        @expected.should eq 10
      end

      it 'aliases #catch for #rescue' do
        @expected = nil
        subject.catch { @expected = true }
        subject.post { raise StandardError }
        sleep(0.1)
        @expected.should be_true
      end

      it 'aliases #on_error for #rescue' do
        @expected = nil
        subject.on_error { @expected = true }
        subject.post { raise StandardError }
        sleep(0.1)
        @expected.should be_true
      end
    end
  end
end

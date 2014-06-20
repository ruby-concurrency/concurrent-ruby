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

    context '#send_off' do
      subject { Agent.new 2, executor: executor }

      it 'executes post and post-off in order' do
        subject.post { |v| v + 2 }
        subject.post_off { |v| v * 3 }
        subject.await
        subject.value.should eq 12
      end
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
        subject.post { |value| 10 }
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable

      # observable

      subject { Agent.new(0) }

      def trigger_observable(observable)
        observable.post { nil }
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
        agent.post { |value| 0 }
      end

      it 'uses the global operation pool when :operation is true' do
        Concurrent.configuration.should_receive(:global_operation_pool).and_return(executor)
        agent = Agent.new(0, operation: true)
        agent.post { |value| 0 }
      end

      it 'uses the global task pool when :task is true' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        agent = Agent.new(0, task: true)
        agent.post { |value| 0 }
      end

      it 'uses the global task pool by default' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        agent = Agent.new(0)
        agent.post { |value| 0 }
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
        executor.should_receive(:post).with(no_args).exactly(1).times
        subject.post { sleep(1) }
        subject.post { nil }
        subject.post { nil }
        sleep(0.1)
        subject.
            instance_variable_get(:@serialized_execution).
            instance_variable_get(:@stash).
            size.should eq 2
      end

      it 'does not add to the queue when no block is given' do
        executor.should_receive(:post).with(no_args).exactly(0).times
        subject.post
        sleep(0.1)
      end

      it 'works with ImmediateExecutor' do
        agent = Agent.new(0, executor: ImmediateExecutor.new)
        agent.post { |old| old + 1 }
        agent.post { |old| old + 1 }
        agent.value.should eq 2
      end

    end

    context '#await' do

      it 'waits until already sent updates are done' do
        fn = false
        subject.post { fn = true; sleep 0.1 }
        subject.await
        fn.should be_true
      end

      it 'does not waits until updates sent after are done' do
        fn = false
        subject.await
        subject.post { fn = true; sleep 0.1 }
        fn.should be_false
      end

      it 'does not alter the value' do
        subject.post { |v| v + 1 }
        subject.await
        subject.value.should eq 1
      end

    end

    context 'fulfillment', :brittle, :refactored do

      it 'process each block in the queue' do
        latch = Concurrent::CountDownLatch.new(3)
        subject.post { latch.count_down }
        subject.post { latch.count_down }
        subject.post { latch.count_down }
        latch.wait(1).should be_true
      end

      it 'passes the current value to the handler' do
        latch = Concurrent::CountDownLatch.new(5)
        Agent.new(latch.count, executor: executor).post do |i|
          i.times{ latch.count_down }
        end
        latch.wait(1).should be_true
      end

      it 'sets the value to the handler return value on success' do
        agent = Agent.new(10, executor: Concurrent::ImmediateExecutor.new)
        agent.value.should eq 10
        agent.post { 100 }
        agent.value.should eq 100
      end

      it 'rejects the handler after timeout reached' do
        agent = Agent.new(0, timeout: 0.1, executor: executor)
        agent.post { sleep(1); 10 }
        sleep(0.2)
        agent.value.should eq 0
      end
    end

    context 'validation', :brittle, :refactored do

      it 'processes the validator when present' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.validate { latch.count_down; true }
        subject.post { nil }
        latch.wait(1).should be_true
      end

      it 'passes the new value to the validator' do
        expected = Concurrent::AtomicFixnum.new(0)
        latch = Concurrent::CountDownLatch.new(1)
        subject.validate { |v| expected.value = v; latch.count_down; true }
        subject.post { 10 }
        latch.wait(1)
        expected.value.should eq 10
      end

      it 'sets the new value when the validator returns true' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).validate { true }
        agent.post { 10 }
        agent.value.should eq 10
      end

      it 'does not change the value when the validator returns false' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).validate { false }
        agent.post { 10 }
        agent.value.should eq 0
      end

      it 'does not change the value when the validator raises an exception' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).validate { raise StandardError }
        agent.post { 10 }
        agent.value.should eq 0
      end
    end

    context 'rejection', :brittle, :refactored do

      it 'calls the first exception block with a matching class' do
        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(StandardError) { |ex| expected = 1 }.
            rescue(StandardError) { |ex| expected = 2 }.
            rescue(StandardError) { |ex| expected = 3 }
        agent.post { raise StandardError }
        expected.should eq 1
      end

      it 'matches all with a rescue with no class given' do
        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(LoadError) { |ex| expected = 1 }.
            rescue { |ex| expected = 2 }.
            rescue(StandardError) { |ex| expected = 3 }
        agent.post { raise NoMethodError }
        expected.should eq 2
      end

      it 'searches associated rescue handlers in order' do
        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(ArgumentError) { |ex| expected = 1 }.
            rescue(LoadError) { |ex| expected = 2 }.
            rescue(StandardError) { |ex| expected = 3 }
        agent.post { raise ArgumentError }
        expected.should eq 1

        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(ArgumentError) { |ex| expected = 1 }.
            rescue(LoadError) { |ex| expected = 2 }.
            rescue(StandardError) { |ex| expected = 3 }
        agent.post { raise LoadError }
        expected.should eq 2

        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(ArgumentError) { |ex| expected = 1 }.
            rescue(LoadError) { |ex| expected = 2 }.
            rescue(StandardError) { |ex| expected = 3 }
        agent.post { raise StandardError }
        expected.should eq 3
      end

      it 'passes the exception object to the matched block' do
        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(ArgumentError) { |ex| expected = ex }.
            rescue(LoadError) { |ex| expected = ex }.
            rescue(StandardError) { |ex| expected = ex }
        agent.post { raise StandardError }
        expected.should be_a(StandardError)
      end

      it 'ignores rescuers without a block' do
        expected = nil
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
            rescue(StandardError).
            rescue(StandardError) { |ex| expected = ex }
        agent.post { raise StandardError }
        expected.should be_a(StandardError)
      end

      it 'supresses the exception if no rescue matches' do
        lambda {
          agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).
              rescue(ArgumentError) { |ex| @expected = ex }.
              rescue(NotImplementedError) { |ex| @expected = ex }.
              rescue(NoMethodError) { |ex| @expected = ex }
          agent.post { raise StandardError }
        }.should_not raise_error
      end

      it 'suppresses exceptions thrown from rescue handlers' do
        lambda {
          agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new).rescue(StandardError) { raise StandardError }
          agent.post { raise ArgumentError }
        }.should_not raise_error
      end
    end

    context 'observation', :brittle, :refactored do

      it 'notifies all observers when the value changes' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        agent.add_observer(observer)
        agent.post { 10 }
        observer.value.should eq 10
      end

      it 'does not notify removed observers when the value changes' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        agent.add_observer(observer)
        agent.delete_observer(observer)
        agent.post { 10 }
        observer.value.should be_nil
      end

      it 'does not notify observers when validation fails' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        agent.validate { false }
        agent.add_observer(observer)
        agent.post { 10 }
        observer.value.should be_nil
      end

      it 'does not notify observers when the handler raises an exception' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        agent.add_observer(observer)
        agent.post { raise StandardError }
        observer.value.should be_nil
      end
    end

    context 'clojure-like behaviour' do
      it 'does not block dereferencing when updating the value' do
        continue = IVar.new
        agent    = Agent.new(0, executor: executor)
        agent.post { |old| old + continue.value }
        sleep 0.1
        Concurrent.timeout(0.2) { agent.value.should eq 0 }
        continue.set 1
        sleep 0.1
      end

      it 'does not allow to execute two updates at the same time' do
        agent     = Agent.new(0, executor: executor)
        continue1 = IVar.new
        continue2 = IVar.new
        f1        = f2 = false
        agent.post { |old| f1 = true; old + continue1.value }
        agent.post { |old| f2 = true; old + continue2.value }

        sleep 0.1
        f1.should eq true
        f2.should eq false
        agent.value.should eq 0

        continue1.set 1
        sleep 0.1
        f1.should eq true
        f2.should eq true
        agent.value.should eq 1

        continue2.set 1
        sleep 0.1
        f1.should eq true
        f2.should eq true
        agent.value.should eq 2
      end

      it 'waits with sending functions to other agents until update is done'
    end

    context 'aliases', :brittle, :refactored do

      it 'aliases #deref for #value' do
        Agent.new(10, executor: executor).deref.should eq 10
      end

      it 'aliases #validates for :validate' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.validates { latch.count_down; true }
        subject.post { nil }
        latch.wait(1).should be_true
      end

      it 'aliases #validate_with for :validate' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.validate_with { latch.count_down; true }
        subject.post { nil }
        latch.wait(1).should be_true
      end

      it 'aliases #validates_with for :validate' do
        latch = Concurrent::CountDownLatch.new(1)
        subject.validates_with { latch.count_down; true }
        subject.post { nil }
        latch.wait(1).should be_true
      end

      it 'aliases #catch for #rescue' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        expected = nil
        agent.catch { expected = true }
        agent.post { raise StandardError }
        agent.should be_true
      end

      it 'aliases #on_error for #rescue' do
        agent = Agent.new(0, executor: Concurrent::ImmediateExecutor.new)
        expected = nil
        agent.on_error { expected = true }
        agent.post { raise StandardError }
        agent.should be_true
      end
    end
  end
end

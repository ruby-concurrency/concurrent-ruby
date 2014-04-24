require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'
require_relative 'observable_shared'

module Concurrent

  describe Future do

    let!(:value) { 10 }
    let(:executor) { PerThreadExecutor.new }

    subject do
      Future.new(executor: executor){
        value
      }.execute.tap{ sleep(0.1) }
    end

    context 'behavior' do

      # obligation

      let!(:fulfilled_value) { 10 }
      let!(:rejected_reason) { StandardError.new('mojo jojo') }

      let(:pending_subject) do
        Future.new(executor: executor){ sleep(3); fulfilled_value }.execute
      end

      let(:fulfilled_subject) do
        Future.new(executor: executor){ fulfilled_value }.execute.tap{ sleep(0.1) }
      end

      let(:rejected_subject) do
        Future.new(executor: executor){ raise rejected_reason }.execute.tap{ sleep(0.1) }
      end

      it_should_behave_like :obligation

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        opts = opts.merge(executor: executor)
        Future.new(opts){ value }.execute.tap{ sleep(0.1) }
      end

      def dereferenceable_observable(opts = {})
        opts = opts.merge(executor: executor)
        Future.new(opts){ 'value' }
      end

      def execute_dereferenceable(subject)
        subject.execute
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable

      # observable
      
      subject{ Future.new{ nil } }
      
      def trigger_observable(observable)
        observable.execute
        sleep(0.1)
      end

      it_should_behave_like :observable
    end

    context 'subclassing' do

      subject{ Future.execute(executor: executor){ 42 } }

      it 'protects #set' do
        expect{ subject.set(100) }.to raise_error
      end

      it 'protects #fail' do
        expect{ subject.fail }.to raise_error
      end

      it 'protects #complete' do
        expect{ subject.complete(true, 100, nil) }.to raise_error
      end
    end

    context '#initialize' do

      let(:executor) { ImmediateExecutor.new }

      it 'sets the state to :unscheduled' do
        Future.new(executor: executor){ nil }.should be_unscheduled
      end

      it 'raises an exception when no block given' do
        expect {
          Future.new.execute
        }.to raise_error(ArgumentError)
      end

      it 'uses the executor given with the :executor option' do
        executor.should_receive(:post)
        Future.execute(executor: executor){ nil }
      end

      it 'uses the global operation pool when :operation is true' do
        Concurrent.configuration.should_receive(:global_operation_pool).and_return(executor)
        Future.execute(operation: true){ nil }
      end

      it 'uses the global task pool when :task is true' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        Future.execute(task: true){ nil }
      end

      it 'uses the global task pool by default' do
        Concurrent.configuration.should_receive(:global_task_pool).and_return(executor)
        Future.execute{ nil }
      end
    end

    context 'instance #execute' do

      it 'does nothing unless the state is :unscheduled' do
        executor = ImmediateExecutor.new
        executor.should_not_receive(:post).with(any_args)
        future = Future.new(executor: executor){ nil }
        future.instance_variable_set(:@state, :pending)
        future.execute
        future.instance_variable_set(:@state, :rejected)
        future.execute
        future.instance_variable_set(:@state, :fulfilled)
        future.execute
      end

      it 'posts the block given on construction' do
        executor.should_receive(:post).with(any_args)
        future = Future.new(executor: executor){ nil }
        future.execute
      end

      it 'sets the state to :pending' do
        future = Future.new(executor: executor){ sleep(0.1) }
        future.execute
        future.should be_pending
      end

      it 'returns self' do
        future = Future.new(executor: executor){ nil }
        future.execute.should be future
      end
    end

    context 'class #execute' do

      let(:executor) { ImmediateExecutor.new }

      it 'creates a new Future' do
        future = Future.execute(executor: executor){ nil }
        future.should be_a(Future)
      end

      it 'passes the block to the new Future' do
        @expected = false
        Future.execute(executor: executor){ @expected = true }
        @expected.should be_true
      end

      it 'calls #execute on the new Future' do
        future = double('future')
        Future.stub(:new).with(any_args).and_return(future)
        future.should_receive(:execute).with(no_args)
        Future.execute{ nil }
      end
    end

    context 'fulfillment' do

      let(:executor) { ImmediateExecutor.new }

      it 'passes all arguments to handler' do
        @expected = false
        Future.new(executor: executor){ @expected = true }.execute
        @expected.should be_true
      end

      it 'sets the value to the result of the handler' do
        future = Future.new(executor: executor){ 42 }.execute
        future.value.should eq 42
      end

      it 'sets the state to :fulfilled when the block completes' do
        future = Future.new(executor: executor){ 42 }.execute
        future.should be_fulfilled
      end

      it 'sets the value to nil when the handler raises an exception' do
        future = Future.new(executor: executor){ raise StandardError }.execute
        future.value.should be_nil
      end

      it 'sets the state to :rejected when the handler raises an exception' do
        future = Future.new(executor: executor){ raise StandardError }.execute
        future.should be_rejected
      end

      context 'aliases' do

        it 'aliases #realized? for #fulfilled?' do
          subject.should be_realized
        end

        it 'aliases #deref for #value' do
          subject.deref.should eq value
        end
      end
    end

    context 'observation' do

      let(:executor) { ImmediateExecutor.new }

      let(:clazz) do
        Class.new do
          attr_reader :value
          attr_reader :reason
          attr_reader :count
          define_method(:update) do |time, value, reason|
            @count = @count.to_i + 1
            @value = value
            @reason = reason
          end
        end
      end

      let(:observer) { clazz.new }

      it 'notifies all observers on fulfillment' do
        future = Future.new(executor: executor){ 42 }
        future.add_observer(observer)

        future.execute

        observer.value.should == 42
        observer.reason.should be_nil
      end

      it 'notifies all observers on rejection' do
        future = Future.new(executor: executor){ raise StandardError }
        future.add_observer(observer)

        future.execute

        observer.value.should be_nil
        observer.reason.should be_a(StandardError)
      end

      it 'notifies an observer added after fulfillment' do
        future = Future.new(executor: executor){ 42 }.execute
        future.add_observer(observer)
        observer.value.should == 42
      end

      it 'notifies an observer added after rejection' do
        future = Future.new(executor: executor){ raise StandardError }.execute
        future.add_observer(observer)
        observer.reason.should be_a(StandardError)
      end

      it 'does not notify existing observers when a new observer added after fulfillment' do
        future = Future.new(executor: executor){ 42 }.execute
        future.add_observer(observer)

        observer.count.should == 1

        o2 = clazz.new
        future.add_observer(o2)

        observer.count.should == 1
        o2.value.should == 42
      end

      it 'does not notify existing observers when a new observer added after rejection' do
        future = Future.new(executor: executor){ raise StandardError }.execute
        future.add_observer(observer)

        observer.count.should == 1

        o2 = clazz.new
        future.add_observer(o2)

        observer.count.should == 1
        o2.reason.should be_a(StandardError)
      end

      context 'deadlock avoidance' do

        def reentrant_observer(future)
          obs = Object.new
          obs.define_singleton_method(:update) do |time, value, reason|
            @value = future.value
          end
          obs.define_singleton_method(:value) { @value }
          obs
        end

        it 'should notify observers outside mutex lock' do
          future = Future.new(executor: executor){ 42 }
          obs = reentrant_observer(future)

          future.add_observer(obs)
          future.execute

          obs.value.should eq 42
        end

        it 'should notify a new observer added after fulfillment outside lock' do
          future = Future.new(executor: executor){ 42 }.execute
          obs = reentrant_observer(future)

          future.add_observer(obs)

          obs.value.should eq 42
        end
      end
    end
  end
end

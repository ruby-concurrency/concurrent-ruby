require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe Future do

    let!(:value) { 10 }
    subject { Future.new{ value }.execute.tap{ sleep(0.1) } }

    before(:each) do
      Future.thread_pool = NullThreadPool.new
    end

    context 'behavior' do

      # uses_global_thread_pool

      let!(:thread_pool_user){ Future }
      it_should_behave_like Concurrent::UsesGlobalThreadPool

      # obligation

      let!(:fulfilled_value) { 10 }
      let!(:rejected_reason) { StandardError.new('mojo jojo') }

      let(:pending_subject) do
        Future.new{ sleep(3); fulfilled_value }.execute
      end

      let(:fulfilled_subject) do
        Future.new{ fulfilled_value }.execute.tap{ sleep(0.1) }
      end

      let(:rejected_subject) do
        Future.new{ raise rejected_reason }.execute.tap{ sleep(0.1) }
      end

      it_should_behave_like :obligation

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        Future.new(opts){ value }.execute.tap{ sleep(0.1) }
      end

      def dereferenceable_observable(opts = {})
        Future.new(opts){ 'value' }
      end

      def execute_dereferenceable(subject)
        subject.execute
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable
    end

    context 'subclassing' do
      
      subject{ Future.execute{ 42 } }

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

      it 'sets the state to :unscheduled' do
        Future.new{ nil }.should be_unscheduled
      end

      it 'does not spawn a new thread' do
        Future.thread_pool.should_not_receive(:post).with(any_args)
        Thread.should_not_receive(:new).with(any_args)
        Future.new{ nil }
      end

      it 'raises an exception when no block given' do
        expect {
          Future.new.execute
        }.to raise_error(ArgumentError)
      end
    end

    context 'instance #execute' do

      it 'does nothing unless the state is :unscheduled' do
        Future.should_not_receive(:thread_pool).with(any_args)
        future = Future.new{ nil }
        future.instance_variable_set(:@state, :pending)
        future.execute
        future.instance_variable_set(:@state, :rejected)
        future.execute
        future.instance_variable_set(:@state, :fulfilled)
        future.execute
      end

      it 'posts the block given on construction' do
        Future.thread_pool.should_receive(:post).with(any_args)
        future = Future.new { nil }
        future.execute
      end

      it 'sets the state to :pending' do
        future = Future.new { sleep(0.1) }
        future.execute
        future.should be_pending
      end

      it 'returns self' do
        future = Future.new { nil }
        future.execute.should be future
      end
    end

    context 'class #execute' do

      before(:each) do
        Future.thread_pool = ImmediateExecutor.new
      end

      it 'creates a new Future' do
        future = Future.execute{ nil }
        future.should be_a(Future)
      end

      it 'passes the block to the new Future' do
        @expected = false
        Future.execute { @expected = true }
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

      before(:each) do
        Future.thread_pool = ImmediateExecutor.new
      end

      it 'passes all arguments to handler' do
        @expected = false
        Future.new{ @expected = true }.execute
        @expected.should be_true
      end

      it 'sets the value to the result of the handler' do
        future = Future.new{ 42 }.execute
        future.value.should eq 42
      end

      it 'sets the state to :fulfilled when the block completes' do
        future = Future.new{ 42 }.execute
        future.should be_fulfilled
      end

      it 'sets the value to nil when the handler raises an exception' do
        future = Future.new{ raise StandardError }.execute
        future.value.should be_nil
      end

      it 'sets the state to :rejected when the handler raises an exception' do
        future = Future.new{ raise StandardError }.execute
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

      before(:each) do
        Future.thread_pool = ImmediateExecutor.new
      end

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
        future = Future.new{ 42 }
        future.add_observer(observer)

        future.execute

        observer.value.should == 42
        observer.reason.should be_nil
      end

      it 'notifies all observers on rejection' do
        future = Future.new{ raise StandardError }
        future.add_observer(observer)

        future.execute

        observer.value.should be_nil
        observer.reason.should be_a(StandardError)
      end

      it 'notifies an observer added after fulfillment' do
        future = Future.new{ 42 }.execute
        future.add_observer(observer)
        observer.value.should == 42
      end

      it 'notifies an observer added after rejection' do
        future = Future.new{ raise StandardError }.execute
        future.add_observer(observer)
        observer.reason.should be_a(StandardError)
      end

      it 'does not notify existing observers when a new observer added after fulfillment' do
        future = Future.new{ 42 }.execute
        future.add_observer(observer)

        observer.count.should == 1

        o2 = clazz.new
        future.add_observer(o2)

        observer.count.should == 1
        o2.value.should == 42
      end

      it 'does not notify existing observers when a new observer added after rejection' do
        future = Future.new{ raise StandardError }.execute
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
          future = Future.new{ 42 }
          obs = reentrant_observer(future)

          future.add_observer(obs)
          future.execute

          obs.value.should eq 42
        end

        it 'should notify a new observer added after fulfillment outside lock' do
          future = Future.new{ 42 }.execute
          obs = reentrant_observer(future)

          future.add_observer(obs)

          obs.value.should eq 42
        end
      end
    end
  end
end

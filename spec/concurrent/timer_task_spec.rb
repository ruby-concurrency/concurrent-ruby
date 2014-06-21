require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'observable_shared'

module Concurrent

  describe TimerTask do
    before(:each) do
      # suppress deprecation warnings.
      Concurrent::TimerTask.any_instance.stub(:warn)
      Concurrent::TimerTask.stub(:warn)
    end

    context :dereferenceable do

      def kill_subject
        @subject.kill if @subject
      rescue Exception => ex
        # prevent exceptions with mocks in tests
      end

      after(:each) do
        kill_subject
      end

      def dereferenceable_subject(value, opts = {})
        kill_subject
        opts     = opts.merge(execution_interval: 0.1, run_now: true)
        @subject = TimerTask.new(opts) { value }.execute.tap { sleep(0.1) }
      end

      def dereferenceable_observable(opts = {})
        opts     = opts.merge(execution_interval: 0.1, run_now: true)
        @subject = TimerTask.new(opts) { 'value' }
      end

      def execute_dereferenceable(subject)
        subject.execute
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable
    end

    context :observable do

      subject { TimerTask.new(execution_interval: 0.1) { nil } }

      after(:each) { subject.kill }

      def trigger_observable(observable)
        observable.execute
        sleep(0.2)
      end

      it_should_behave_like :observable
    end

    context 'created with #new' do

      context '#initialize' do

        it 'raises an exception if no block given' do
          lambda {
            Concurrent::TimerTask.new
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not greater than zero' do
          lambda {
            Concurrent::TimerTask.new(execution_interval: 0) { nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not an integer' do
          lambda {
            Concurrent::TimerTask.new(execution_interval: 'one') { nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not greater than zero' do
          lambda {
            Concurrent::TimerTask.new(timeout_interval: 0) { nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not an integer' do
          lambda {
            Concurrent::TimerTask.new(timeout_interval: 'one') { nil }
          }.should raise_error(ArgumentError)
        end

        it 'uses the default execution interval when no interval is given' do
          subject = TimerTask.new { nil }
          subject.execution_interval.should eq TimerTask::EXECUTION_INTERVAL
        end

        it 'uses the default timeout interval when no interval is given' do
          subject = TimerTask.new { nil }
          subject.timeout_interval.should eq TimerTask::TIMEOUT_INTERVAL
        end

        it 'uses the given execution interval' do
          subject = TimerTask.new(execution_interval: 5) { nil }
          subject.execution_interval.should eq 5
        end

        it 'uses the given timeout interval' do
          subject = TimerTask.new(timeout_interval: 5) { nil }
          subject.timeout_interval.should eq 5
        end
      end

      context '#kill' do

        it 'returns true on success' do
          task = TimerTask.execute(run_now: false) { nil }
          sleep(0.1)
          task.kill.should be_true
        end
      end
    end

    context 'arguments' do

      it 'raises an exception if no block given' do
        lambda {
          Concurrent::TimerTask.execute
        }.should raise_error
      end

      specify '#execution_interval is writeable' do

        latch   = CountDownLatch.new(1)
        subject = TimerTask.new(timeout_interval: 1,
                                execution_interval: 1,
                                run_now: true) do |task|
          task.execution_interval = 3
          latch.count_down
        end

        subject.execution_interval.should == 1
        subject.execution_interval = 0.1
        subject.execution_interval.should == 0.1

        subject.execute
        latch.wait(0.2)

        subject.execution_interval.should == 3
        subject.kill
      end

      specify '#timeout_interval is writeable' do

        latch   = CountDownLatch.new(1)
        subject = TimerTask.new(timeout_interval: 1,
                                execution_interval: 0.1,
                                run_now: true) do |task|
          task.timeout_interval = 3
          latch.count_down
        end

        subject.timeout_interval.should == 1
        subject.timeout_interval = 2
        subject.timeout_interval.should == 2

        subject.execute
        latch.wait(0.2)

        subject.timeout_interval.should == 3
        subject.kill
      end
    end

    context 'execution' do

      it 'runs the block immediately when the :run_now option is true' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 500, now: true) { latch.count_down }
        latch.wait(1).should be_true
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is false' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 0.1, now: false) { latch.count_down }
        latch.count.should eq 1
        latch.wait(1).should be_true
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is not given' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 0.1, now: false) { latch.count_down }
        latch.count.should eq 1
        latch.wait(1).should be_true
        subject.kill
      end

      it 'passes a "self" reference to the block as the sole argument' do
        expected = nil
        latch    = CountDownLatch.new(1)
        subject  = TimerTask.new(execution_interval: 1, run_now: true) do |task|
          expected = task
          latch.sount_down
        end
        subject.execute
        latch.wait(1)
        expected.should eq subject
        subject.kill
      end
    end

    context 'observation' do

      let(:observer) do
        Class.new do
          attr_reader :time
          attr_reader :value
          attr_reader :ex
          attr_reader :latch
          define_method(:initialize) { @latch = CountDownLatch.new(1) }
          define_method(:update) do |time, value, ex|
            @time  = time
            @value = value
            @ex    = ex
            @latch.count_down
          end
        end.new
      end

      it 'notifies all observers on success' do
        subject = TimerTask.new(execution: 0.1) { 42 }
        subject.add_observer(observer)
        subject.execute
        observer.latch.wait(1)
        observer.value.should == 42
        observer.ex.should be_nil
        subject.kill
      end

      it 'notifies all observers on timeout' do
        subject = TimerTask.new(execution: 0.1, timeout: 0.1) { sleep }
        subject.add_observer(observer)
        subject.execute
        observer.latch.wait(1)
        observer.value.should be_nil
        observer.ex.should be_a(Concurrent::TimeoutError)
        subject.kill
      end

      it 'notifies all observers on error' do
        subject = TimerTask.new(execution: 0.1) { raise ArgumentError }
        subject.add_observer(observer)
        subject.execute
        observer.latch.wait(1)
        observer.value.should be_nil
        observer.ex.should be_a(ArgumentError)
        subject.kill
      end
    end
  end
end

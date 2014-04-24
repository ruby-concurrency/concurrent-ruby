require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'observable_shared'
require_relative 'runnable_shared'

module Concurrent

  describe TimerTask do

    before(:each) do
      # suppress deprecation warnings.
      Concurrent::TimerTask.any_instance.stub(:warn)
      Concurrent::TimerTask.stub(:warn)
    end

    after(:each) do
      @subject = @subject.runner if @subject.respond_to?(:runner)
      @subject.kill unless @subject.nil?
      @thread.kill unless @thread.nil?
      sleep(0.1)
    end

    context :runnable do

      subject { TimerTask.new{ nil } }

      it_should_behave_like :runnable
    end

    context :dereferenceable do

      def dereferenceable_subject(value, opts = {})
        opts = opts.merge(execution_interval: 0.1, run_now: true)
        TimerTask.new(opts){ value }.execute.tap{ sleep(0.1) }
      end

      def dereferenceable_observable(opts = {})
        opts = opts.merge(execution_interval: 0.1, run_now: true)
        TimerTask.new(opts){ 'value' }
      end

      def execute_dereferenceable(subject)
        subject.execute
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable
    end

    context :observable do
      
      subject{ TimerTask.new(execution_interval: 0.1){ nil } }
      
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
            @subject = Concurrent::TimerTask.new
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not greater than zero' do
          lambda {
            @subject = Concurrent::TimerTask.new(execution_interval: 0){ nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not an integer' do
          lambda {
            @subject = Concurrent::TimerTask.new(execution_interval: 'one'){ nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not greater than zero' do
          lambda {
            @subject = Concurrent::TimerTask.new(timeout_interval: 0){ nil }
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not an integer' do
          lambda {
            @subject = Concurrent::TimerTask.new(timeout_interval: 'one'){ nil }
          }.should raise_error(ArgumentError)
        end

        it 'uses the default execution interval when no interval is given' do
          @subject = TimerTask.new{ nil }
          @subject.execution_interval.should eq TimerTask::EXECUTION_INTERVAL
        end

        it 'uses the default timeout interval when no interval is given' do
          @subject = TimerTask.new{ nil }
          @subject.timeout_interval.should eq TimerTask::TIMEOUT_INTERVAL
        end

        it 'uses the given execution interval' do
          @subject = TimerTask.new(execution_interval: 5){ nil }
          @subject.execution_interval.should eq 5
        end

        it 'uses the given timeout interval' do
          @subject = TimerTask.new(timeout_interval: 5){ nil }
          @subject.timeout_interval.should eq 5
        end
      end

      context '#kill' do

        it 'returns true on success' do
          task = TimerTask.new(run_now: false){ nil }
          task.run!
          sleep(0.1)
          task.kill.should be_true
        end
      end
    end

    context 'created with TimerTask.run!' do

      context 'arguments' do

        it 'raises an exception if no block given' do
          lambda {
            @subject = Concurrent::TimerTask.run
          }.should raise_error
        end

        it 'passes the block to the new TimerTask' do
          @expected = false
          block = proc{ @expected = true }
          @subject = TimerTask.run!(run_now: true, &block)
          sleep(0.1)
          @expected.should be_true
        end

        it 'creates a new thread' do
          thread = Thread.new{ sleep(1) }
          Thread.should_receive(:new).with(any_args()).and_return(thread)
          @subject = TimerTask.run!{ nil }
        end

        specify '#execution_interval is writeable' do
          @subject = TimerTask.new(execution_interval: 1) do |task|
            task.execution_interval = 3
          end
          @subject.execution_interval.should == 1
          @subject.execution_interval = 0.1
          @subject.execution_interval.should == 0.1
          @thread = Thread.new { @subject.run }
          sleep(0.2)
          @subject.execution_interval.should == 3
        end

        specify '#execution_interval is writeable' do
          @subject = TimerTask.new(timeout_interval: 1, execution_interval: 0.1) do |task|
            task.timeout_interval = 3
          end
          @subject.timeout_interval.should == 1
          @subject.timeout_interval = 2
          @subject.timeout_interval.should == 2
          @thread = Thread.new { @subject.run }
          sleep(0.2)
          @subject.timeout_interval.should == 3
        end
      end
    end

    context 'execution' do

      it 'runs the block immediately when the :run_now option is true' do
        @expected = false
        @subject = TimerTask.run!(execution: 500, now: true){ @expected = true }
        sleep(0.1)
        @expected.should be_true
      end

      it 'waits for :execution_interval seconds when the :run_now option is false' do
        @expected = false
        @subject = TimerTask.run!(execution: 0.5, now: false){ @expected = true }
        @expected.should be_false
        sleep(1)
        @expected.should be_true
      end

      it 'waits for :execution_interval seconds when the :run_now option is not given' do
        @expected = false
        @subject = TimerTask.run!(execution: 0.5){ @expected = true }
        @expected.should be_false
        sleep(1)
        @expected.should be_true
      end

      it 'yields to the execution block' do
        @expected = false
        @subject = TimerTask.run!(execution: 1){ @expected = true }
        sleep(2)
        @expected.should be_true
      end

      it 'passes a "self" reference to the block as the sole argument' do
        @expected = nil
        @subject = TimerTask.new(execution_interval: 1, run_now: true) do |task|
          @expected = task
        end
        @thread = Thread.new { @subject.run }
        sleep(0.2)
        @expected.should eq @subject
      end
    end

    context 'observation' do

      let(:observer) do
        Class.new do
          attr_reader :time
          attr_reader :value
          attr_reader :ex
          define_method(:update) do |time, value, ex|
            @time = time
            @value = value
            @ex = ex
          end
        end.new
      end

      it 'notifies all observers on success' do
        task = TimerTask.new(run_now: true){ sleep(0.1); 42 }
        task.add_observer(observer)
        Thread.new{ task.run }
        sleep(1)
        observer.value.should == 42
        observer.ex.should be_nil
        task.kill
      end

      it 'notifies all observers on timeout' do
        task = TimerTask.new(run_now: true, timeout: 1){ sleep }
        task.add_observer(observer)
        Thread.new{ task.run }
        sleep(2)
        observer.value.should be_nil
        observer.ex.should be_a(Concurrent::TimeoutError)
        task.kill
      end

      it 'notifies all observers on error' do
        task = TimerTask.new(run_now: true){ sleep(0.1); raise ArgumentError }
        task.add_observer(observer)
        Thread.new{ task.run }
        sleep(1)
        observer.value.should be_nil
        observer.ex.should be_a(ArgumentError)
        task.kill
      end
    end
  end
end

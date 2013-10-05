require 'spec_helper'

module Concurrent

  describe Runnable do

    let(:runnable_without_callbacks) do
      Class.new {
        include Runnable
        attr_reader :thread
        def on_task
          @thread = Thread.current
          sleep(0.1)
        end
      }
    end

    let(:runnable_with_callbacks) do
      Class.new(runnable_without_callbacks) do
        def on_run() return true; end
        def on_stop() return true; end
      end
    end

    subject { runnable_without_callbacks.new }

    after(:each) do
      @thread.kill unless @thread.nil?
    end

    context '#run' do

      it 'starts the (blocking) runner on the current thread when stopped' do
        @thread = Thread.new { subject.run }
        @thread.join(1).should be_nil
      end

      it 'calls #on_run when implemented' do
        runner = runnable_with_callbacks.new
        runner.should_receive(:on_run).with(no_args())
        @thread = Thread.new { runner.run }
        sleep(0.1)
      end

      it 'does not attempt to call #on_run when not implemented' do
        runner = runnable_without_callbacks.new
        @thread = Thread.new do
          expect {
            runner.run
          }.not_to raise_error
        end
        sleep(0.1)
      end

      it 'raises an exception when already running' do
        @thread = Thread.new { subject.run }
        sleep(0.1)
        expect {
          subject.run
        }.to raise_error(Runnable::LifecycleError)
      end

      it 'returns true when stopped normally' do
        @expected = false
        @thread = Thread.new { @expected = subject.run }
        sleep(0.1)
        subject.stop
        sleep(0.1)
        @expected.should be_true
      end

      it 'returns false when the task loop raises an exception' do
        @expected = false
        subject.stub(:on_task).and_raise(StandardError)
        @thread = Thread.new { @expected = subject.run }
        sleep(0.1)
        @expected.should be_false
      end

      it 'return false when #on_run raises an exception' do
        @expected = true
        subject.stub(:on_run).and_raise(StandardError)
        @thread = Thread.new do
          @expected = subject.run
        end
        sleep(0.1)
        @expected.should be_false
      end

      it 'raises an exception if the #on_task callback is not implemented' do
        runner = Class.new { include Runnable }.new
        expect {
          runner.run
        }.to raise_error(Runnable::LifecycleError)
      end

      it 'calls #on_task in an infinite loop' do
        subject.should_receive(:on_task).with(no_args()).at_least(1)
        @thread = Thread.new { subject.run }
        @thread.join(1)
      end
    end

    context '#stop' do

      it 'calls #on_stop when implemented' do
        runner = runnable_with_callbacks.new
        runner.should_receive(:on_stop).with(no_args())
        @thread = Thread.new { runner.run }
        sleep(0.1)
        runner.stop
        sleep(0.1)
      end

      it 'does not attempt to call #on_stop when not implemented' do
        runner = runnable_without_callbacks.new
        @thread = Thread.new { runner.run }
        sleep(0.1)
        expect {
          runner.stop
        }.not_to raise_error
      end

      it 'returns true when not running' do
        subject.stop.should be_true
      end

      it 'returns true when successfully stopped' do
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.stop.should be_true
      end

      it 'return false when #on_stop raises an exception' do
        subject.stub(:on_stop).and_raise(StandardError)
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.stop.should be_false
      end
    end

    context '#running?' do

      it 'returns true when running' do
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.should be_running
      end

      it 'returns false when not running' do
        subject.should_not be_running
      end

      it 'returns false if runner abends' do
        subject.stub(:on_task).and_raise(StandardError)
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.should_not be_running
      end
    end

    context '#run!' do

      let(:runnable) { runnable_without_callbacks }

      after(:each) do
        @context.runner.stop if @context && @context.runner
        @context.thread.kill if @context && @context.thread
      end

      it 'creates a new runner' do
        runnable.should_receive(:new).once.with(no_args())
        @context = runnable.run!
        sleep(0.1)
      end

      it 'passes all args to the runner constructor' do
        args = [1, 2, :three, :four]
        runnable.should_receive(:new).once.with(*args)
        @context = runnable.run!(*args)
        sleep(0.1)
      end

      it 'creates a new thread' do
        Thread.should_receive(:new).with(any_args()).and_return(nil)
        @context = runnable.run!
        sleep(0.1)
      end

      it 'runs the runner on the new thread' do
        @context = runnable.run!
        sleep(0.1)
        @context.runner.thread.should_not eq Thread.current
        @context.runner.thread.should eq @context.thread
      end

      it 'returns a context object on success' do
        @context = runnable.run!
        sleep(0.1)
        @context.should be_a(Runnable::Context)
      end

      it 'returns nil on failure' do
        Thread.stub(:new).with(any_args()).and_raise(StandardError)
        @context = runnable.run!
        sleep(0.1)
        @context.should be_nil
      end
    end
  end
end

require 'spec_helper'
require_relative 'runnable_shared'

module Concurrent

  describe Runnable do

    let(:runnable) do
      Class.new {
        include Runnable
        attr_reader :thread
        def initialize(*args, &block)
          yield if block_given?
        end
        def on_task
          @thread = Thread.current
          sleep(0.1)
        end
        def on_run() return true; end
        def on_stop() return true; end
      }
    end

    subject { runnable.new }

    it_should_behave_like :runnable

    after(:each) do
      subject.stop
      @thread.kill unless @thread.nil?
    end

    context '#run' do

      it 'calls #on_run when implemented' do
        subject.should_receive(:on_run).with(no_args())
        @thread = Thread.new { subject.run }
        sleep(0.1)
      end

      it 'does not attempt to call #on_run when not implemented' do
        subject.class.send(:remove_method, :on_run)
        @thread = Thread.new do
          expect {
            subject.run
          }.not_to raise_error
        end
        sleep(0.1)
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

      it 'calls #on_task in an infinite loop' do
        subject.should_receive(:on_task).with(no_args()).at_least(1)
        @thread = Thread.new { subject.run }
        @thread.join(1)
      end

      it 'raises an exception if the #on_task callback is not implemented' do
        runner = Class.new { include Runnable }.new
        expect {
          runner.run
        }.to raise_error(Runnable::LifecycleError)
      end
    end

    context '#stop' do

      it 'calls #on_stop when implemented' do
        subject.should_receive(:on_stop).with(no_args())
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.stop
        sleep(0.1)
      end

      it 'does not attempt to call #on_stop when not implemented' do
        subject.class.send(:remove_method, :on_stop)
        @thread = Thread.new { subject.run }
        sleep(0.1)
        expect {
          subject.stop
        }.not_to raise_error
      end

      it 'return false when #on_stop raises an exception' do
        subject.stub(:on_stop).and_raise(StandardError)
        @thread = Thread.new { subject.run }
        sleep(0.1)
        subject.stop.should be_false
        subject.should_not be_running
      end
    end

    context '#running?' do

      it 'returns false if runner abends' do
        subject.stub(:on_task).and_raise(StandardError)
        @thread = Thread.new { subject.run }
        @thread.join(0.1)
        subject.should_not be_running
      end
    end

    context '#run!' do

      let(:clazz) do
        Class.new { include Runnable }
      end

      after(:each) do
        @context.runner.stop if @context && @context.runner
        @context.thread.kill if @context && @context.thread
      end

      it 'creates a new runner' do
        clazz.should_receive(:new).once.with(no_args())
        @context = clazz.run!
        sleep(0.1)
      end

      it 'passes all args to the runner constructor' do
        args = [1, 2, :three, :four]
        clazz.should_receive(:new).once.with(*args)
        @context = clazz.run!(*args)
        sleep(0.1)
      end

      it 'passes a block argument to the runner constructor' do
        @expected = false
        @context = runnable.run!{ @expected = true }
        sleep(0.1)
        @expected.should be_true
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
        @context.thread.should_not eq Thread.current
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

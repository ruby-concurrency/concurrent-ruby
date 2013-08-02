require 'spec_helper'

module Concurrent

  describe Executor do

    after(:each) do
      Thread.kill(@ec.thread) if @ec.is_a?(ExecutionContext) && @ec.thread.is_a?(Thread)
    end

    context '#run' do

      it 'raises an exception if no block given' do
        lambda {
          @ec = Concurrent::Executor.run('Foo')
        }.should raise_error
      end

      it 'uses the default execution interval when no interval is given' do
        @ec = Executor.run('Foo'){ nil }
        @ec.execution_interval.should eq Executor::EXECUTION_INTERVAL
      end

      it 'uses the default timeout interval when no interval is given' do
        @ec = Executor.run('Foo'){ nil }
        @ec.timeout_interval.should eq Executor::TIMEOUT_INTERVAL
      end

      it 'uses the given execution interval' do
        @ec = Executor.run('Foo', execution_interval: 5){ nil }
        @ec.execution_interval.should eq 5
      end

      it 'uses the given timeout interval' do
        @ec = Executor.run('Foo', timeout_interval: 5){ nil }
        @ec.timeout_interval.should eq 5
      end

      it 'creates a new thread' do
        thread_double = double('executor thread')
        Thread.should_receive(:new).with(no_args()).and_return(thread_double)
        @ec = Executor.run('Foo'){ nil }
      end

      it 'returns an ExecutionContext' do
        @ec = Executor.run('Foo'){ nil }
        @ec.should be_a(ExecutionContext)
      end

      it 'sets the #name context variable' do
        @ec = Executor.run('Foo'){ nil }
        @ec.name.should eq 'Foo'
      end
    end

    context 'execution' do

      it 'waits for #execution_interval seconds before executing the block' do
        @expected = false
        @ec = Executor.run('Foo', execution: 0.5){ @expected = true }
        @expected.should be_false
        sleep(1)
        @expected.should be_true
      end

      it 'yields to the execution block' do
        @expected = false
        @ec = Executor.run('Foo', execution: 1){ @expected = true }
        sleep(2)
        @expected.should be_true
      end

      it 'passes any given arguments to the execution block' do
        args = [1,2,3,4]
        @expected = nil
        @ec = Executor.run('Foo', execution_interval: 0.5, args: args) do |*args|
          @expected = args
        end
        sleep(1)
        @expected.should eq args
      end

      it 'supresses exceptions thrown by the execution block' do
        lambda {
          @ec = Executor.run('Foo', execution_interval: 0.5) { raise StandardError }
          sleep(1)
        }.should_not raise_error
      end

      it 'kills the worker thread if the timeout is reached' do
        # the after(:each) block will trigger this expectation
        Thread.should_receive(:kill).at_least(1).with(any_args())
        @ec = Executor.run('Foo', execution_interval: 0.5, timeout_interval: 0.5){ sleep(2) }
        sleep(1.5)
      end
    end

    context 'logging' do

      before(:each) do
        @name = nil
        @level = nil
        @msg = nil

        @logger = proc do |name, level, msg|
          @name = name
          @level = level
          @msg = msg
        end
      end

      it 'uses a custom logger when given' do
        @ec = Executor.run('Foo', execution_interval: 0.1, logger: @logger){ nil }
        sleep(0.5)
        @name.should eq 'Foo'
      end

      it 'logs :info when execution is successful' do
        @ec = Executor.run('Foo', execution_interval: 0.1, logger: @logger){ nil }
        sleep(0.5)
        @level.should eq :info
      end

      it 'logs :warn when execution times out' do
        @ec = Executor.run('Foo', execution_interval: 0.1, timeout_interval: 0.1, logger: @logger){ sleep(2) }
        sleep(0.5)
        @level.should eq :warn
      end

      it 'logs :error when execution is fails' do
        @ec = Executor.run('Foo', execution_interval: 0.1, logger: @logger){ raise StandardError }
        sleep(0.5)
        @level.should eq :error
      end
    end
  end
end

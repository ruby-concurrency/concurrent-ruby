require 'spec_helper'

module Concurrent

  describe Executor do

    before(:each) do
      @orig_stdout = $stdout
      $stdout = StringIO.new 
    end

    after(:each) do
      $stdout = @orig_stdout
    end

    after(:each) do
      @subject.kill unless @subject.nil?
    end

    context 'created with #new' do

      context '#initialize' do

        it 'raises an exception if no block given' do
          lambda {
            @subject = Concurrent::Executor.new('Foo')
          }.should raise_error
        end

        it 'uses the default execution interval when no interval is given' do
          @subject = Executor.new('Foo'){ nil }
          @subject.execution_interval.should eq Executor::EXECUTION_INTERVAL
        end

        it 'uses the default timeout interval when no interval is given' do
          @subject = Executor.new('Foo'){ nil }
          @subject.timeout_interval.should eq Executor::TIMEOUT_INTERVAL
        end

        it 'uses the given execution interval' do
          @subject = Executor.new('Foo', execution_interval: 5){ nil }
          @subject.execution_interval.should eq 5
        end

        it 'uses the given timeout interval' do
          @subject = Executor.new('Foo', timeout_interval: 5){ nil }
          @subject.timeout_interval.should eq 5
        end

        it 'sets the #name context variable' do
          @subject = Executor.new('Foo'){ nil }
          @subject.name.should eq 'Foo'
        end
      end

      context '#run!' do

        it 'runs the block immediately when the :run_now option is true' do
          @expected = false
          @subject = Executor.new('Foo', execution: 500, now: true){ @expected = true }
          @subject.run!
          sleep(0.1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is false' do
          @expected = false
          @subject = Executor.new('Foo', execution: 0.5, now: false){ @expected = true }
          @subject.run!
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is not given' do
          @expected = false
          @subject = Executor.new('Foo', execution: 0.5){ @expected = true }
          @subject.run!
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'yields to the execution block' do
          @expected = false
          @subject = Executor.new('Foo', execution: 1){ @expected = true }
          @subject.run!
          sleep(2)
          @expected.should be_true
        end

        it 'passes any given arguments to the execution block' do
          args = [1,2,3,4]
          @expected = nil
          @subject = Executor.new('Foo', execution_interval: 0.5, args: args) do |*args|
            @expected = args
          end
          @subject.run!
          sleep(1)
          @expected.should eq args
        end

        it 'supresses exceptions thrown by the execution block' do
          lambda {
            @subject = Executor.new('Foo', execution_interval: 0.5) { raise StandardError }
            @subject.run!
            sleep(1)
          }.should_not raise_error
        end

        it 'kills the worker thread if the timeout is reached' do
          # the after(:each) block will trigger this expectation
          Thread.should_receive(:kill).at_least(1).with(any_args())
          @subject = Executor.new('Foo', execution_interval: 0.5, timeout_interval: 0.5){ Thread.stop }
          @subject.run!
          sleep(1.5)
        end
      end

      context '#run' do
        pending
      end

      context '#stop' do
        pending
      end

      context '#kill' do
        pending
      end

      context '#running?' do

        it 'returns false when first created' do
          @subject = Executor.new('Foo'){ nil }
          @subject.should_not be_running
        end

        it 'returns true when the monitor is running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          @subject.should be_running
        end

        it 'returns false if the monitor exits' do
          monitor = Thread.new{ nil }
          Thread.should_receive(:new).with(no_args()).and_return(monitor)
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          sleep(0.1)
          @subject.should_not be_running
        end

        it 'returns false if the monitor crashes' do
          monitor = Thread.new{ raise StandardException }
          Thread.should_receive(:new).with(no_args()).and_return(monitor)
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          sleep(0.1)
          @subject.should_not be_running
        end

        it 'returns false after stopped' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          sleep(0.1)
          @subject.stop
          @subject.should_not be_running
        end

        it 'returns false after killed' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          sleep(0.1)
          @subject.kill
          @subject.should_not be_running
        end
      end

      context '#status' do

        it 'returns the status of the executor thread when running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          sleep(0.1)
          @subject.status.should eq 'sleep'
        end

        it 'returns nil when not running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.status.should be_nil
        end
      end

      context '#join' do

        it 'joins the executor thread when running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          Thread.new{ sleep(1); @subject.kill }
          @subject.join.should be_a(Thread)
        end

        it 'joins the executor thread with timeout when running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.run!
          @subject.join(1).should be_nil
        end

        it 'immediately returns nil when not running' do
          @subject = Executor.new('Foo'){ nil }
          @subject.join.should be_nil
          @subject.join(1).should be_nil
        end
      end
    end

    context 'created with Executor.run' do

      context 'arguments' do

        it 'raises an exception if no block given' do
          lambda {
            @subject = Concurrent::Executor.run('Foo')
          }.should raise_error
        end

        it 'passes the name to the new Executor' do
          @subject = Executor.new('Foo'){ nil }
          Executor.should_receive(:new).with('Foo', anything()).and_return(@subject)
          Concurrent::Executor.run('Foo')
        end

        it 'passes the options to the new Executor' do
          opts = {
            execution_interval: 100,
            timeout_interval: 100,
            run_now: false,
            logger: proc{ nil },
            block_args: %w[one two three]
          }
          @subject = Executor.new('Foo', opts){ nil }
          Executor.should_receive(:new).with(anything(), opts).and_return(@subject)
          Concurrent::Executor.run('Foo', opts)
        end

        it 'passes the block to the new Executor' do
          @expected = false
          block = proc{ @expected = true }
          @subject = Executor.run('Foo', run_now: true, &block)
          sleep(0.1)
          @expected.should be_true
        end

        it 'creates a new thread' do
          thread = Thread.new{ sleep(1) }
          Thread.should_receive(:new).with(any_args()).and_return(thread)
          @subject = Executor.run('Foo'){ nil }
        end

        it 'returns an Executor' do
          @subject = Executor.run('Foo'){ nil }
          @subject.should be_a(Executor)
          # backward compaibility
          @subject.should be_a(Executor::ExecutionContext)
        end
      end

      context 'execution' do

        it 'runs the block immediately when the :run_now option is true' do
          @expected = false
          @subject = Executor.run('Foo', execution: 500, now: true){ @expected = true }
          sleep(0.1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is false' do
          @expected = false
          @subject = Executor.run('Foo', execution: 0.5, now: false){ @expected = true }
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is not given' do
          @expected = false
          @subject = Executor.run('Foo', execution: 0.5){ @expected = true }
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'yields to the execution block' do
          @expected = false
          @subject = Executor.run('Foo', execution: 1){ @expected = true }
          sleep(2)
          @expected.should be_true
        end

        it 'passes any given arguments to the execution block' do
          args = [1,2,3,4]
          @expected = nil
          @subject = Executor.run('Foo', execution_interval: 0.5, args: args) do |*args|
            @expected = args
          end
          sleep(1)
          @expected.should eq args
        end

        it 'supresses exceptions thrown by the execution block' do
          lambda {
            @subject = Executor.run('Foo', execution_interval: 0.5) { raise StandardError }
            sleep(1)
          }.should_not raise_error
        end

        it 'kills the worker thread if the timeout is reached' do
          # the after(:each) block will trigger this expectation
          Thread.should_receive(:kill).at_least(1).with(any_args())
          @subject = Executor.run('Foo', execution_interval: 0.5, timeout_interval: 0.5){ Thread.stop }
          sleep(1.5)
        end
      end

      context '#status' do

        it 'returns the status of the executor thread when running' do
          @subject = Executor.run('Foo'){ nil }
          sleep(0.1)
          @subject.status.should eq 'sleep'
        end

        it 'returns nil when not running' do
          @subject = Executor.run('Foo'){ nil }
          sleep(0.1)
          @subject.kill
          sleep(0.1)
          @subject.status.should be_nil
        end
      end

      context '#join' do

        it 'joins the executor thread when running' do
          @subject = Executor.run('Foo'){ nil }
          Thread.new{ sleep(1); @subject.kill }
          @subject.join.should be_a(Thread)
        end

        it 'joins the executor thread with timeout when running' do
          @subject = Executor.run('Foo'){ nil }
          @subject.join(1).should be_nil
        end

        it 'immediately returns nil when not running' do
          @subject = Executor.run('Foo'){ nil }
          sleep(0.1)
          @subject.kill
          sleep(0.1)
          @subject.join.should be_nil
          @subject.join(1).should be_nil
        end
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
        @subject = Executor.run('Foo', execution_interval: 0.1, logger: @logger){ nil }
        sleep(0.5)
        @name.should eq 'Foo'
      end

      it 'logs :info when execution is successful' do
        @subject = Executor.new('Foo', execution_interval: 0.1, logger: @logger){ nil }
        @subject.run!
        sleep(0.5)
        @level.should eq :info
      end

      it 'logs :warn when execution times out' do
        @subject = Executor.run('Foo', execution_interval: 0.1, timeout_interval: 0.1, logger: @logger){ Thread.stop }
        sleep(0.5)
        @level.should eq :warn
      end

      it 'logs :error when execution is fails' do
        @subject = Executor.new('Foo', execution_interval: 0.1, logger: @logger){ raise StandardError }
        @subject.run!
        sleep(0.5)
        @level.should eq :error
      end
    end
  end
end

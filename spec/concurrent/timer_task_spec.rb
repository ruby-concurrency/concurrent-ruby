require 'spec_helper'
require_relative 'runnable_shared'

module Concurrent

  describe TimerTask do

    before(:each) do
      @orig_stdout = $stdout
      $stdout = StringIO.new 
    end

    after(:each) do
      $stdout = @orig_stdout
    end

    after(:each) do
      @subject = @subject.runner if @subject.respond_to?(:runner)
      @subject.kill unless @subject.nil?
      @thread.kill unless @thread.nil?
      sleep(0.1)
    end

    context ':runnable' do

      subject { TimerTask.new(':runnable'){ nil } }

      it_should_behave_like :runnable
    end

    context 'created with #new' do

      context '#initialize' do

        it 'raises an exception if no block given' do
          lambda {
            @subject = Concurrent::TimerTask.new('Foo')
          }.should raise_error
        end

        it 'uses the default execution interval when no interval is given' do
          @subject = TimerTask.new('Foo'){ nil }
          @subject.execution_interval.should eq TimerTask::EXECUTION_INTERVAL
        end

        it 'uses the default timeout interval when no interval is given' do
          @subject = TimerTask.new('Foo'){ nil }
          @subject.timeout_interval.should eq TimerTask::TIMEOUT_INTERVAL
        end

        it 'uses the given execution interval' do
          @subject = TimerTask.new('Foo', execution_interval: 5){ nil }
          @subject.execution_interval.should eq 5
        end

        it 'uses the given timeout interval' do
          @subject = TimerTask.new('Foo', timeout_interval: 5){ nil }
          @subject.timeout_interval.should eq 5
        end

        it 'sets the #name context variable' do
          @subject = TimerTask.new('Foo'){ nil }
          @subject.name.should eq 'Foo'
        end
      end

      context '#kill' do
        pending
      end
    end

    context 'created with TimerTask.run!' do

      context 'arguments' do

        it 'raises an exception if no block given' do
          lambda {
            @subject = Concurrent::TimerTask.run('Foo')
          }.should raise_error
        end

        it 'passes the name to the new TimerTask' do
          @subject = TimerTask.new('Foo'){ nil }
          TimerTask.should_receive(:new).with('Foo').and_return(@subject)
          Concurrent::TimerTask.run!('Foo')
        end

        it 'passes the options to the new TimerTask' do
          opts = {
            execution_interval: 100,
            timeout_interval: 100,
            run_now: false,
            logger: proc{ nil },
            block_args: %w[one two three]
          }
          @subject = TimerTask.new('Foo', opts){ nil }
          TimerTask.should_receive(:new).with(anything(), opts).and_return(@subject)
          Concurrent::TimerTask.run!('Foo', opts)
        end

        it 'passes the block to the new TimerTask' do
          @expected = false
          block = proc{ @expected = true }
          @subject = TimerTask.run!('Foo', run_now: true, &block)
          sleep(0.1)
          @expected.should be_true
        end

        it 'creates a new thread' do
          thread = Thread.new{ sleep(1) }
          Thread.should_receive(:new).with(any_args()).and_return(thread)
          @subject = TimerTask.run!('Foo'){ nil }
        end
      end

      context 'execution' do

        it 'runs the block immediately when the :run_now option is true' do
          @expected = false
          @subject = TimerTask.run!('Foo', execution: 500, now: true){ @expected = true }
          sleep(0.1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is false' do
          @expected = false
          @subject = TimerTask.run!('Foo', execution: 0.5, now: false){ @expected = true }
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'waits for :execution_interval seconds when the :run_now option is not given' do
          @expected = false
          @subject = TimerTask.run!('Foo', execution: 0.5){ @expected = true }
          @expected.should be_false
          sleep(1)
          @expected.should be_true
        end

        it 'yields to the execution block' do
          @expected = false
          @subject = TimerTask.run!('Foo', execution: 1){ @expected = true }
          sleep(2)
          @expected.should be_true
        end

        it 'passes any given arguments to the execution block' do
          args = [1,2,3,4]
          @expected = nil
          @subject = TimerTask.new('Foo', execution_interval: 0.5, args: args) do |*args|
            @expected = args
          end
          @thread = Thread.new { @subject.run }
          sleep(1)
          @expected.should eq args
        end

        it 'kills the worker thread if the timeout is reached' do
          # the after(:each) block will trigger this expectation
          Thread.should_receive(:kill).at_least(1).with(any_args())
          @subject = TimerTask.new('Foo', execution_interval: 0.5, timeout_interval: 0.5){ Thread.stop }
          @thread = Thread.new { @subject.run }
          sleep(1.5)
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
        @subject = TimerTask.run!('Foo', execution_interval: 0.1, logger: @logger){ nil }
        sleep(0.5)
        @name.should eq 'Foo'
      end

      it 'logs :info when execution is successful' do
        @subject = TimerTask.run!('Foo', execution_interval: 0.1, logger: @logger){ nil }
        sleep(0.5)
        @level.should eq :info
      end

      it 'logs :warn when execution times out' do
        @subject = TimerTask.run!('Foo', execution_interval: 0.1, timeout_interval: 0.1, logger: @logger){ Thread.stop }
        sleep(0.5)
        @level.should eq :warn
      end

      it 'logs :error when execution is fails' do
        @subject = TimerTask.run!('Foo', execution_interval: 0.1, logger: @logger){ raise StandardError }
        sleep(0.5)
        @level.should eq :error
      end
    end
  end
end

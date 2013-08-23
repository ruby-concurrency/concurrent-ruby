require 'spec_helper'

module Concurrent

  describe Supervisor do

    let(:worker_class) do
      Class.new {
        behavior(:runnable)
        def run() return true; end
        def stop() return true; end
        def running?() return true; end
      }
    end

    let(:worker){ worker_class.new }

    subject{ Supervisor.new }

    after(:each) do
      subject.stop
    end

    context '#initialize' do

      it 'sets the initial length to zero' do
        supervisor = Supervisor.new
        supervisor.length.should == 0
      end

      it 'sets the initial length to one when a worker is provided' do
        supervisor = Supervisor.new(worker: worker)
        supervisor.length.should == 1
      end

      it 'sets the initial state to stopped' do
        supervisor = Supervisor.new
        supervisor.should_not be_running
      end

      it 'sets the monitor interval when given' do
        supervisor = Supervisor.new
        supervisor.monitor_interval.should == Supervisor::DEFAULT_MONITOR_INTERVAL
      end

      it 'sets the monitor interval to the default when not given' do
        supervisor = Supervisor.new(monitor_interval: 5)
        supervisor.monitor_interval.should == 5

        supervisor = Supervisor.new(monitor: 10)
        supervisor.monitor_interval.should == 10
      end

      it 'raises an exception when given an invalid restart strategy' do
        Supervisor::STRATEGIES.each do |strategy|
          lambda {
            supervisor = Supervisor.new(strategy: strategy)
          }.should_not raise_error
        end

        lambda {
          supervisor = Supervisor.new(strategy: :bogus)
        }.should raise_error(ArgumentError)
      end

      it 'uses :one_for_one as the default restart strategy' do
        supervisor = Supervisor.new
        supervisor.should_receive(:one_for_one)
        supervisor.run!
        sleep(0.1)
        supervisor.stop
      end
    end

    context 'run' do

      it 'runs the monitor' do
        subject.should_receive(:monitor).with(no_args()).at_least(1).times
        t = Thread.new{ subject.run }
        sleep(0.1)
        subject.stop
        Thread.kill(t) unless t.nil?
      end

      it 'calls #run on all workers' do
        supervisor = Supervisor.new(worker: worker)
        # must stub AFTER adding or else #add_worker will reject
        worker.should_receive(:run).with(no_args())
        t = Thread.new{ supervisor.run }
        sleep(0.1)
        supervisor.stop
        Thread.kill(t)
      end

      it 'sets the state to running' do
        t = Thread.new{ subject.run }
        sleep(0.1)
        subject.should be_running
        subject.stop
        Thread.kill(t)
      end

      it 'raises an exception when already running' do
        @thread = nil
        subject.run!
        lambda {
          @thread = Thread.new{ subject.run }
          @thread.abort_on_exception = true
          sleep(0.1)
        }.should raise_error(StandardError)
        subject.stop
        Thread.kill(@thread) unless @thread.nil?
      end
    end

    context '#run!' do

      it 'runs the monitor thread' do
        thread = Thread.new{ nil }
        Thread.should_receive(:new).with(no_args()).and_return(thread)
        subject.run!
      end

      it 'calls #run on all workers' do
        supervisor = Supervisor.new(worker: worker)
        # must stub AFTER adding or else #add_worker will reject
        worker.should_receive(:run).with(no_args())
        supervisor.run!
        sleep(0.1)
      end

      it 'sets the state to running' do
        subject.run!
        subject.should be_running
      end

      it 'raises an exception when already running' do
        subject.run!
        lambda {
          subject.run!
        }.should raise_error(StandardError)
      end
    end

    context '#stop' do

      it 'stops the monitor thread' do
        Thread.should_receive(:kill).with(anything())
        subject.run!
        sleep(0.1)
        subject.stop
      end

      it 'calls #stop on all workers' do
        workers = (1..3).collect{ worker_class.new }
        workers.each{|worker| subject.add_worker(worker)}
        # must stub AFTER adding or else #add_worker will reject
        workers.each{|worker| worker.should_receive(:stop).with(no_args())}
        subject.run!
        sleep(0.1)
        subject.stop
      end

      it 'sets the state to stopped' do
        subject.run!
        subject.stop
        subject.should_not be_running
      end

      it 'returns true immediately when already stopped' do
        subject.stop.should be_true
      end

      it 'unblocks a thread blocked by #run and exits normally' do
        supervisor = Supervisor.new(monitor: 0.1)
        @thread = Thread.new{ sleep(0.5); supervisor.stop }
        sleep(0.1)
        lambda {
          Timeout::timeout(1){ supervisor.run }
        }.should_not raise_error
        Thread.kill(@thread) unless @thread.nil?
      end
    end

    context '#running?' do

      it 'returns true when running' do
        subject.run!
        subject.should be_running
      end

      it 'returns false when stopped' do
        subject.run!
        subject.stop
        subject.should_not be_running
      end
    end

    context '#length' do

      it 'returns a count of attached workers' do
        workers = (1..3).collect{ worker.dup }
        workers.each{|worker| subject.add_worker(worker)}
        subject.length.should == 3
      end
    end

    context '#add_worker' do

      it 'adds the worker when stopped' do
        subject.add_worker(worker)
        subject.length.should == 1
      end

      it 'rejects the worker when running' do
        subject.run!
        subject.add_worker(worker)
        subject.length.should == 0
      end

      it 'rejects a worker without the :runnable behavior' do
        subject.add_worker('bogus worker')
        subject.length.should == 0
      end

      it 'returns true when a worker is accepted' do
        subject.add_worker(worker).should be_true
      end

      it 'returns false when a worker is not accepted' do
        subject.add_worker('bogus worker').should be_false
      end
    end

    context 'restart strategirs' do

      context ':one_for_one' do

        it 'reruns any worker that stops' do
          worker = Class.new(worker_class){
            def run() sleep(0.2); end
          }.new

          supervisor = Supervisor.new(worker: worker, monitor: 0.1)
          supervisor.add_worker(worker)
          # must stub AFTER adding or else #add_worker will reject
          worker.should_receive(:run).with(no_args()).at_least(2).times
          supervisor.run!
          sleep(1)
          supervisor.stop
        end

        it 'reruns any dead threads' do
          worker = Class.new(worker_class){
            def run() raise StandardError; end
          }.new

          supervisor = Supervisor.new(worker: worker, monitor: 0.1)
          supervisor.add_worker(worker)
          # must stub AFTER adding or else #add_worker will reject
          worker.should_receive(:run).with(no_args()).at_least(2).times
          supervisor.run!
          sleep(1)
          supervisor.stop
        end
      end

      context ':one_for_all' do
        pending
      end

      context ':rest_for_one' do
        pending
      end
    end

    context 'supervisor tree' do

      specify do
        s1 = Supervisor.new(monitor: 0.1)
        s2 = Supervisor.new(monitor: 0.1)
        s3 = Supervisor.new(monitor: 0.1)

        workers = (1..3).collect{ worker_class.new }
        workers.each{|worker| s3.add_worker(worker)}
        # must stub AFTER adding or else #add_worker will reject
        workers.each{|worker| worker.should_receive(:run).at_least(1).times.with(no_args())}
        workers.each{|worker| worker.should_receive(:stop).at_least(1).times.with(no_args())}

        s1.add_worker(s2)
        s2.add_worker(s3)

        s1.run!
        sleep(0.2)
        s1.stop
        sleep(0.2)
      end
    end
  end
end

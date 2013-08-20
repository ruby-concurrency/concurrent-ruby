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
    end

    context '#run' do

      it 'runs the monitor thread' do
        Thread.should_receive(:new).with(no_args())
        subject.run
      end

      it 'calls #run on all workers' do
        supervisor = Supervisor.new(worker: worker)
        # must stub AFTER adding or else #add_worker will reject
        worker.should_receive(:run).with(no_args())
        supervisor.run
        sleep(0.1)
      end

      it 'sets the state to running' do
        subject.run
        subject.should be_running
      end

      it 'raises an exception when already running' do
        subject.run
        lambda {
          subject.run
        }.should raise_error(StandardError)
      end
    end

    context '#stop' do

      it 'stops the monitor thread' do
        monitor = double('monitor thread')
        Thread.should_receive(:new).with(no_args()).and_return(monitor)
        Thread.should_receive(:kill).with(monitor)
        subject.run
        subject.stop
      end

      it 'calls #stop on all workers' do
        workers = (1..3).collect{ worker_class.new }
        workers.each{|worker| subject.add_worker(worker)}
        # must stub AFTER adding or else #add_worker will reject
        workers.each{|worker| worker.should_receive(:stop).with(no_args())}
        subject.run
        subject.stop
      end

      it 'sets the state to stopped' do
        subject.run
        subject.stop
        subject.should_not be_running
      end

      it 'returns true immediately when already stopped' do
        subject.stop.should be_true
      end
    end

    context '#running?' do

      it 'returns true when running' do
        subject.run
        subject.should be_running
      end

      it 'returns false when stopped' do
        subject.run
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
        subject.run
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

    context 'supervision' do

      it 'reruns any worker that stops' do
        worker = Class.new(worker_class){
          def run() sleep(0.2); end
        }.new

        supervisor = Supervisor.new(worker: worker, monitor: 0.1)
        supervisor.add_worker(worker)
        # must stub AFTER adding or else #add_worker will reject
        worker.should_receive(:run).with(no_args()).at_least(2).times
        supervisor.run
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
        supervisor.run
        sleep(1)
        supervisor.stop
      end
    end
  end
end

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

    let(:sleeper_class) do
      Class.new(worker_class) {
        def run() sleep; end
      }
    end

    let(:stopper_class) do
      Class.new(worker_class) {
        def initialize(sleep_time = 0.2) @sleep_time = sleep_time; end;
        def run() sleep(@sleep_time); end
      }
    end

    let(:error_class) do
      Class.new(worker_class) {
        def run() raise StandardError; end
      }
    end

    let(:worker){ worker_class.new }

    subject{ Supervisor.new(strategy: :one_for_one) }

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

      it 'uses the given monitor interval' do
        supervisor = Supervisor.new
        supervisor.monitor_interval.should == Supervisor::DEFAULT_MONITOR_INTERVAL
      end

      it 'uses the default monitor interval when none given' do
        supervisor = Supervisor.new(monitor_interval: 5)
        supervisor.monitor_interval.should == 5
      end

      it 'raises an exception when given an invalid monitor interval' do
        lambda {
          Supervisor.new(monitor_interval: -1)
        }.should raise_error(ArgumentError)

        lambda {
          Supervisor.new(monitor_interval: 'bogus')
        }.should raise_error(ArgumentError)
      end

      it 'uses the given restart strategy' do
        supervisor = Supervisor.new(restart_strategy: :rest_for_one)
        supervisor.restart_strategy.should eq :rest_for_one
      end

      it 'uses :one_for_one when no restart strategy given' do
        supervisor = Supervisor.new
        supervisor.restart_strategy.should eq :one_for_one
      end

      it 'raises an exception when given an invalid restart strategy' do
        Supervisor::RESTART_STRATEGIES.each do |strategy|
          lambda {
            supervisor = Supervisor.new(strategy: strategy)
          }.should_not raise_error
        end

        lambda {
          supervisor = Supervisor.new(strategy: :bogus)
        }.should raise_error(ArgumentError)
      end

      it 'uses the given maximum restart value' do
        supervisor = Supervisor.new(max_restart: 3)
        supervisor.max_r.should == 3

        supervisor = Supervisor.new(max_r: 3)
        supervisor.max_restart.should == 3
      end

      it 'uses the default maximum restart value when none given' do
        supervisor = Supervisor.new
        supervisor.max_restart.should == Supervisor::DEFAULT_MAX_RESTART
        supervisor.max_r.should == Supervisor::DEFAULT_MAX_RESTART
      end

      it 'raises an exception when given an invalid maximum restart value' do
        lambda {
          Supervisor.new(max_restart: -1)
        }.should raise_error(ArgumentError)

        lambda {
          Supervisor.new(max_restart: 'bogus')
        }.should raise_error(ArgumentError)
      end

      it 'uses the given maximum time value' do
        supervisor = Supervisor.new(max_time: 3)
        supervisor.max_t.should == 3

        supervisor = Supervisor.new(max_t: 3)
        supervisor.max_time.should == 3
      end

      it 'uses the default maximum time value when none given' do
        supervisor = Supervisor.new
        supervisor.max_time.should == Supervisor::DEFAULT_MAX_TIME
        supervisor.max_t.should == Supervisor::DEFAULT_MAX_TIME
      end

      it 'raises an exception when given an invalid maximum time value' do
        lambda {
          Supervisor.new(max_time: -1)
        }.should raise_error(ArgumentError)

        lambda {
          Supervisor.new(max_time: 'bogus')
        }.should raise_error(ArgumentError)
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
        supervisor = Supervisor.new(monitor_interval: 0.1)
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

    context 'maximum restart frequency' do

      it 'terminates all workers then itself when exceeded' do

        workers = [
          sleeper_class.new,
          stopper_class.new(0.1),
          sleeper_class.new
        ]

        supervisor = Supervisor.new(strategy: :one_for_one,
                                    max_restart: 2,
                                    monitor_interval: 0.1)
        workers.each{|worker| supervisor.add_worker(worker) }

        supervisor.run
        supervisor.should_not be_running
      end

      it 'does nothing when :max_r is not exceeded' do

        workers = [
          sleeper_class.new,
          stopper_class.new(1),
          sleeper_class.new
        ]

        supervisor = Supervisor.new(strategy: :one_for_one,
                                    max_restart: 3,
                                    monitor_interval: 0.1)
        workers.each{|worker| supervisor.add_worker(worker) }

        supervisor.run!
        supervisor.should be_running
        sleep(1)
        supervisor.should be_running
        supervisor.stop
      end

      it 'does nothing when :max_r is exceeded but outside :max_t' do
        pending('cannot get the timing right')

        workers = [
          sleeper_class.new,
          stopper_class.new(0.5),
          sleeper_class.new
        ]

        supervisor = Supervisor.new(strategy: :one_for_one,
                                    max_restart: 4,
                                    max_time: 1,
                                    monitor_interval: 0.5)
        workers.each{|worker| supervisor.add_worker(worker) }

        supervisor.run!
        supervisor.should be_running
        sleep(2)
        supervisor.should be_running
        supervisor.stop
      end
    end

    context 'restart strategies' do

      context ':one_for_one' do

        it 'restarts any worker that stops' do

          workers = [
            sleeper_class.new,
            stopper_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :one_for_one, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).once.with(no_args())
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end

        it 'restarts any dead threads' do

          workers = [
            sleeper_class.new,
            error_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :one_for_one, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).once.with(no_args())
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end
      end

      context ':one_for_all' do

        it 'restarts all workers when one stops' do

          workers = [
            sleeper_class.new,
            stopper_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :one_for_all, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).with(no_args()).at_least(2).times
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).with(no_args()).at_least(2).times

          workers[0].should_receive(:stop).once.with(no_args())
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end

        it 'restarts all workers when one thread dies' do

          workers = [
            sleeper_class.new,
            error_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :one_for_all, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).with(no_args()).at_least(2).times
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).with(no_args()).at_least(2).times

          workers[0].should_receive(:stop).once.with(no_args())
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end
      end

      context ':rest_for_one' do

        it 'restarts a stopped worker and all workers added after it' do

          workers = [
            sleeper_class.new,
            stopper_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :rest_for_one, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).once.with(no_args())
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).with(no_args()).at_least(2).times

          workers[0].should_not_receive(:stop)
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end

        it 'restarts a dead worker thread and all workers added after it' do

          workers = [
            sleeper_class.new,
            error_class.new,
            sleeper_class.new
          ]

          supervisor = Supervisor.new(strategy: :rest_for_one, monitor_interval: 0.1)
          workers.each{|worker| supervisor.add_worker(worker) }

          # must stub AFTER adding or else #add_worker will reject
          workers[0].should_receive(:run).once.with(no_args())
          workers[1].should_receive(:run).with(no_args()).at_least(2).times
          workers[2].should_receive(:run).with(no_args()).at_least(2).times

          workers[0].should_not_receive(:stop)
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          supervisor.stop
        end
      end
    end

    context 'supervisor tree' do

      specify do
        s1 = Supervisor.new(monitor_interval: 0.1)
        s2 = Supervisor.new(monitor_interval: 0.1)
        s3 = Supervisor.new(monitor_interval: 0.1)

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

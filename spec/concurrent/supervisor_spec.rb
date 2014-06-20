require 'spec_helper'
require 'timecop'

module Concurrent

  describe Supervisor, :unfinished do

    before do
      # suppress deprecation warnings.
      Concurrent::Supervisor.any_instance.stub(:warn)
      Concurrent::Supervisor.stub(:warn)
    end

    let(:worker_class) do
      Class.new {
        attr_reader :start_count, :stop_count
        def run() @start_count ||= 0; @start_count += 1; return true; end
        def stop() @stop_count ||= 0; @stop_count += 1; return true; end
        def running?() return true; end
      }
    end

    let(:sleeper_class) do
      Class.new(worker_class) {
        def run() super(); sleep; end
      }
    end

    let(:stopper_class) do
      Class.new(worker_class) {
        attr_reader :latch
        def initialize(sleep_time = 0.2)
          @sleep_time = sleep_time
          @latch = Concurrent::CountDownLatch.new(1)
        end
        def run
          super
          sleep(@sleep_time)
          @latch.count_down
        end
      }
    end

    let(:error_class) do
      Class.new(worker_class) {
        def run() super(); raise StandardError; end
      }
    end

    let(:runner_class) do
      Class.new(worker_class) {
        attr_accessor :stopped
        def run()
          super()
          stopped = false
          loop do
            break if stopped
            Thread.pass
          end
        end
        def stop() super(); stopped = true; end
      }
    end

    let(:worker){ worker_class.new }

    subject{ Supervisor.new(strategy: :one_for_one, monitor_interval: 0.1) }

    after(:each) do
      subject.stop
      kill_rogue_threads(false)
      @thread.kill unless @thread.nil?
      sleep(0.1)
    end

    context '#run' do

      it 'starts the (blocking) runner on the current thread when stopped' do
        @thread = Thread.new { subject.run }
        @thread.join(0.1).should be_nil
      end

      it 'raises an exception when already running' do
        @thread = Thread.new { subject.run }
        @thread.join(0.1)
        expect {
          subject.run
        }.to raise_error
      end

      it 'returns true when stopped normally' do
        @expected = false
        @thread = Thread.new { @expected = subject.run }
        @thread.join(0.1)
        subject.stop
        @thread.join(1)
        @expected.should be_true
      end
    end

    context '#stop' do

      it 'returns true when not running' do
        subject.stop.should be_true
      end

      it 'returns true when successfully stopped' do
        @thread = Thread.new { subject.run }
        @thread.join(0.1)
        subject.stop.should be_true
        subject.should_not be_running
      end
    end

    context '#running?' do

      it 'returns true when running' do
        @thread = Thread.new { subject.run }
        @thread.join(0.1)
        subject.should be_running
      end

      it 'returns false when first created' do
        subject.should_not be_running
      end

      it 'returns false when not running' do
        subject.stop
        sleep(0.1)
        subject.should_not be_running
      end
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

    context '#run' do

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
          @thread = Thread.new do
            Thread.current.abort_on_exception = true
            subject.run
          end
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
        sleep(0.1)
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

      def mock_thread(status = 'run')
        thread = double('thread')
        thread.should_receive(:status).with(no_args()).and_return(status)
        thread.stub(:join).with(any_args()).and_return(thread)
        Thread.stub(:new).with(no_args()).and_return(thread)
        return thread
      end

      it 'wakes the monitor thread if sleeping' do
        thread = mock_thread('sleep')
        thread.should_receive(:run).once.with(no_args())

        subject.run!
        sleep(0.1)
        subject.stop
      end

      it 'kills the monitor thread if it does not wake up' do
        thread = mock_thread('run')
        thread.should_receive(:join).with(any_args()).and_return(nil)
        thread.should_receive(:kill).with(no_args())

        subject.run!
        sleep(0.1)
        subject.stop
      end

      it 'calls #stop on all workers' do
        workers = (1..3).collect{ runner_class.new }
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
          Concurrent::timeout(1){ supervisor.run }
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

    context '#count' do

      let(:stoppers){ Array.new }

      let(:busy_supervisor) do
        supervisor = Supervisor.new(monitor_interval: 60)
        3.times do
          supervisor.add_worker(sleeper_class.new)
          supervisor.add_worker(error_class.new)
          supervisor.add_worker(runner_class.new)

          stopper = stopper_class.new
          stoppers << stopper
          supervisor.add_worker(stopper)
        end
        supervisor
      end

      let!(:total_count){ 12 }
      let!(:active_count){ 6 }
      let!(:sleeping_count){ 3 }
      let!(:running_count){ 3 }
      let!(:aborting_count){ 3 }
      let!(:stopped_count){ 3 }
      let!(:abend_count){ 3 }

      after(:each) do
        busy_supervisor.stop
      end

      it 'returns an immutable WorkerCounts object' do
        counts = subject.count
        counts.should be_a(Supervisor::WorkerCounts)

        lambda {
          counts.specs += 1
        }.should raise_error(RuntimeError)
      end

      it 'returns the total worker count as #specs' do
        subject.count.specs.should eq 0

        3.times do
          subject.add_worker(worker_class.new, type: :worker)
          subject.add_worker(worker_class.new, type: :supervisor)
        end

        subject.count.specs.should eq 6
      end

      it 'returns the count of all children marked as :supervisor as #supervisors' do
        subject.count.supervisors.should eq 0

        3.times do
          subject.add_worker(worker_class.new, type: :worker)
          subject.add_worker(worker_class.new, type: :supervisor)
        end

        subject.count.supervisors.should eq 3
      end

      it 'returns the count of all children marked as :worker as #workers' do
        subject.count.workers.should eq 0

        3.times do
          subject.add_worker(worker_class.new, type: :worker)
          subject.add_worker(worker_class.new, type: :supervisor)
        end

        subject.count.workers.should eq 3
      end

      it 'returns the count of all active workers as #active' do
        busy_supervisor.count.active.should eq 0
        busy_supervisor.run!
        sleep(0.5)

        busy_supervisor.count.active.should eq active_count
      end

      it 'returns the count of all sleeping workers as #sleeping' do
        busy_supervisor.count.sleeping.should eq 0
        busy_supervisor.run!
        sleep(0.5)

        busy_supervisor.count.sleeping.should eq sleeping_count
      end

      it 'returns the count of all running workers as #running' do
        busy_supervisor.count.running.should eq 0
        busy_supervisor.run!
        sleep(0.5)

        busy_supervisor.count.running.should eq running_count
      end

      it 'returns the count of all aborting workers as #aborting' do
        busy_supervisor.count.aborting.should eq 0

        count = Supervisor::WorkerCounts.new(5, 0, 5)
        count.status = %w[aborting run aborting false aborting]
        count.aborting.should eq 3
      end

      it 'returns the count of all stopped workers as #stopped' do
        busy_supervisor.count.stopped.should eq total_count
        busy_supervisor.run!
        stoppers.each{|stopper| stopper.latch.wait(1) }
        sleep(0.1)

        busy_supervisor.count.stopped.should eq stopped_count
      end

      it 'returns the count of all workers terminated by exception as #abend' do
        busy_supervisor.count.abend.should eq 0
        busy_supervisor.run!
        stoppers.each{|stopper| stopper.latch.wait(1) }
        sleep(0.1)

        busy_supervisor.count.abend.should eq abend_count
      end
    end

    context '#current_restart_count' do

      it 'is zero for a new Supervisor' do
        subject.current_restart_count.should eq 0
      end

      it 'returns the number of worker restarts' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.3)
        supervisor.current_restart_count.should > 0
        supervisor.stop
      end

      it 'resets to zero on #stop' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.3)
        supervisor.stop
        sleep(0.1)
        supervisor.current_restart_count.should eq 0
      end
    end

    context '#add_worker' do

      it 'adds the worker when stopped' do
        subject.add_worker(worker)
        subject.length.should == 1
      end

      it 'runs the worker when the supervisor is running' do
        worker = worker_class.new
        worker.start_count.to_i.should eq 0
        subject.run!
        sleep(0.1)
        subject.add_worker(worker).should be_true
        sleep(0.1)
        worker.start_count.should >= 1
      end

      it 'rejects a worker without the :runnable behavior' do
        subject.add_worker('bogus worker')
        subject.length.should == 0
      end

      it 'sets the restart type to the given value' do
        subject.add_worker(worker_class.new, restart: :temporary)
        worker = subject.instance_variable_get(:@workers).first
        worker.restart.should eq :temporary
      end

      it 'sets the restart type to :permanent when none given' do
        subject.add_worker(worker_class.new)
        worker = subject.instance_variable_get(:@workers).first
        worker.restart.should eq :permanent
      end

      it 'raises an exception when given an invalid restart type' do
        lambda {
          subject.add_worker(worker_class.new, restart: :bogus)
        }.should raise_error(ArgumentError)
      end

      it 'sets the child type to the given value' do
        subject.add_worker(worker_class.new, type: :supervisor)
        worker = subject.instance_variable_get(:@workers).first
        worker.type.should eq :supervisor
      end

      it 'sets the worker type to :worker when none given' do
        subject.add_worker(worker_class.new)
        worker = subject.instance_variable_get(:@workers).first
        worker.type.should eq :worker
      end

      it 'sets the worker type to :supervisor when #is_a? Supervisor' do
        subject.add_worker(Supervisor.new)
        worker = subject.instance_variable_get(:@workers).first
        worker.type.should eq :supervisor
      end

      it 'raises an exception when given an invalid restart type' do
        lambda {
          subject.add_worker(worker_class.new, type: :bogus)
        }.should raise_error(ArgumentError)
      end

      it 'returns an object id when a worker is accepted' do
        worker_id = subject.add_worker(worker)
        worker_id.should be_a(Integer)
        first = subject.instance_variable_get(:@workers).first
        worker_id.should eq first.object_id
      end

      it 'returns nil when a worker is not accepted' do
        subject.add_worker('bogus worker').should be_nil
      end
    end

    context '#add_workers' do

      it 'calls #add_worker once for each worker' do
        workers = 5.times.collect{ worker_class.new }
        workers.each do |worker|
          subject.should_receive(:add_worker).once.with(worker, anything())
        end
        subject.add_workers(workers)
      end

      it 'passes the options hash to each #add_worker call' do
        options = {
          restart: :permanent,
          type: :worker
        }
        workers = 5.times.collect{ worker_class.new }
        workers.each do |worker|
          subject.should_receive(:add_worker).once.with(anything(), options)
        end
        subject.add_workers(workers, options)
      end

      it 'returns an array of object identifiers' do
        workers = 5.times.collect{ worker_class.new }
        context = subject.add_workers(workers)
        context.size.should == 5
        context.each do |wc|
          wc.should be_a(Fixnum)
        end
      end
    end

    context '#remove_worker' do

      it 'returns false if the worker is running' do
        id = subject.add_worker(sleeper_class.new)
        subject.run!
        sleep(0.1)
        subject.remove_worker(id).should be_false
      end

      it 'returns nil if the worker is not found' do
        subject.run!
        sleep(0.1)
        subject.remove_worker(1234).should be_nil
      end

      it 'returns the worker on success' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 60)
        id = supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.1)
        supervisor.remove_worker(id).should eq worker
        supervisor.stop
      end

      it 'removes the worker from the supervisor on success' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 60)
        id = supervisor.add_worker(worker)
        supervisor.length.should == 1
        supervisor.run!
        sleep(0.1)
        supervisor.remove_worker(id)
        supervisor.length.should == 0
        supervisor.stop
      end
    end

    context '#stop_worker' do

      it 'returns true if the supervisor is not running' do
        worker = worker_class.new
        id = subject.add_worker(worker)
        subject.stop_worker(id).should be_true
      end

      it 'returns nil if the worker is not found' do
        worker = sleeper_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        subject.stop_worker(1234).should be_nil
      end

      it 'returns true on success' do
        worker = sleeper_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        worker.should_receive(:stop).at_least(1).times.and_return(true)
        subject.stop_worker(id).should be_true
      end

      it 'deletes the worker if it is :temporary' do
        worker = sleeper_class.new
        id = subject.add_worker(worker, restart: :temporary)
        subject.size.should eq 1
        subject.run!
        sleep(0.1)
        subject.stop_worker(id).should be_true
        subject.size.should eq 0
      end

      it 'does not implicitly restart the worker' do
        supervisor = Supervisor.new(monitor_interval: 0.1)
        worker = runner_class.new
        id = supervisor.add_worker(worker, restart: :permanent)
        supervisor.run!
        sleep(0.1)
        supervisor.stop_worker(id)
        sleep(0.5)
        supervisor.stop
        worker.start_count.should eq 1
      end
    end

    context '#start_worker' do

      it 'returns false if the supervisor is not running' do
        worker = worker_class.new
        id = subject.add_worker(worker)
        subject.start_worker(id).should be_false
      end

      it 'returns nil if the worker is not found' do
        subject.run!
        sleep(0.1)
        subject.start_worker(1234).should be_nil
      end

      it 'starts the worker if not running' do
        supervisor = Supervisor.new(monitor_interval: 60)
        worker = error_class.new
        id = supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.1)
        supervisor.start_worker(id)
        sleep(0.1)
        worker.start_count.should == 2
        supervisor.stop
      end

      it 'returns true when the worker is successfully started' do
        supervisor = Supervisor.new(monitor_interval: 60)
        worker = error_class.new
        id = supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.1)
        supervisor.start_worker(id).should be_true
        supervisor.stop
      end

      it 'returns true if the worker was already running' do
        supervisor = Supervisor.new(monitor_interval: 60)
        worker = sleeper_class.new
        id = supervisor.add_worker(worker)
        supervisor.run!
        sleep(0.1)
        supervisor.start_worker(id).should be_true
        worker.start_count.should == 1
        supervisor.stop
      end
    end

    context '#restart_worker' do

      it 'returns false if the supervisor is not running' do
        worker = worker_class.new
        id = subject.add_worker(worker)
        subject.restart_worker(id).should be_false
      end

      it 'returns nil if the worker is not found' do
        subject.run!
        sleep(0.1)
        subject.restart_worker(1234).should be_nil
      end

      it 'returns false if the worker is :temporary' do
        worker = worker_class.new
        id = subject.add_worker(worker, restart: :temporary)
        subject.run!
        sleep(0.1)
        subject.restart_worker(id).should be_false
      end

      it 'stops and then starts a worker that is running' do
        worker = runner_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        subject.restart_worker(id)
        sleep(0.1)
        worker.start_count.should == 2
        worker.stop_count.should == 1
      end

      it 'returns true if the worker is running and is successfully restarted' do
        worker = runner_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        subject.restart_worker(id).should be_true
      end

      it 'starts a worker that is not running' do
        worker = error_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        subject.restart_worker(id)
        sleep(0.1)
        worker.start_count.should >= 2
      end

      it 'returns true if the worker is not running and is successfully started' do
        worker = error_class.new
        id = subject.add_worker(worker)
        subject.run!
        sleep(0.1)
        subject.restart_worker(id).should be_true
      end
    end

    context 'maximum restart frequency' do

      context '#exceeded_max_restart_frequency?' do

        # Normally I am very opposed to testing private methods
        # but this functionality has proven extremely difficult to test.
        # Geting the timing right is almost impossible. This is the
        # best approach I could think of.

        it 'increments the restart count on every call' do
          subject.send(:exceeded_max_restart_frequency?)
          subject.current_restart_count.should eq 1

          subject.send(:exceeded_max_restart_frequency?)
          subject.current_restart_count.should eq 2

          subject.send(:exceeded_max_restart_frequency?)
          subject.current_restart_count.should eq 3
        end

        it 'returns false when the restart count is lower than :max_restart' do
          supervisor = Supervisor.new(max_restart: 5, max_time: 60)

          Timecop.freeze do
            4.times do
              Timecop.travel(5)
              supervisor.send(:exceeded_max_restart_frequency?).should be_false
            end

            Timecop.travel(5)
            supervisor.send(:exceeded_max_restart_frequency?).should be_true
          end
        end

        it 'returns false when the restart count is high but the time range is out of scope' do
          supervisor = Supervisor.new(max_restart: 3, max_time: 8)

          Timecop.freeze do
            10.times do
              Timecop.travel(5)
              supervisor.send(:exceeded_max_restart_frequency?).should be_false
            end
          end
        end

        it 'returns true when the restart count is exceeded within the max time range' do
          supervisor = Supervisor.new(max_restart: 2, max_time: 5)
          Timecop.freeze do
            supervisor.send(:exceeded_max_restart_frequency?).should be_false
            Timecop.travel(1)
            supervisor.send(:exceeded_max_restart_frequency?).should be_true
          end
        end
      end

      context 'restarts when true for strategy' do

        specify ':one_for_one' do
          supervisor = Supervisor.new(restart_strategy: :one_for_one,
                                      monitor_interval: 0.1)
          supervisor.add_worker(error_class.new)
          supervisor.stub(:exceeded_max_restart_frequency?).once.and_return(true)
          future = Concurrent::Future.execute{ supervisor.run }
          future.value(1)
          supervisor.should_not be_running
        end

        specify ':one_for_all' do
          supervisor = Supervisor.new(restart_strategy: :one_for_all,
                                      monitor_interval: 0.1)
          supervisor.add_worker(error_class.new)
          supervisor.should_receive(:exceeded_max_restart_frequency?).once.and_return(true)
          future = Concurrent::Future.execute{ supervisor.run }
          future.value(1)
          supervisor.should_not be_running
        end

        specify ':rest_for_one' do
          supervisor = Supervisor.new(restart_strategy: :rest_for_one,
                                      monitor_interval: 0.1)
          supervisor.add_worker(error_class.new)
          supervisor.should_receive(:exceeded_max_restart_frequency?).once.and_return(true)
          future = Concurrent::Future.execute{ supervisor.run }
          future.value(1)
          supervisor.should_not be_running
        end
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

          supervisor.run!
          sleep(1)

          workers[0].start_count.should == 1
          workers[1].start_count.should >= 2
          workers[2].start_count.should == 1

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

          supervisor.run!
          sleep(1)

          workers[0].start_count.should == 1
          workers[1].start_count.should >= 2
          workers[2].start_count.should == 1

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

          workers[0].should_receive(:stop).once.with(no_args())
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          workers.each{|worker| worker.start_count.should >= 2 }

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

          workers[0].should_receive(:stop).once.with(no_args())
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)
          workers.each{|worker| worker.start_count.should >= 2 }

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

          workers[0].should_not_receive(:stop)
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)

          workers[0].start_count.should == 1
          workers[1].start_count.should >= 2
          workers[2].start_count.should >= 2

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

          workers[0].should_not_receive(:stop)
          workers[2].should_receive(:stop).once.with(no_args())

          supervisor.run!
          sleep(1)

          workers[0].start_count.should == 1
          workers[1].start_count.should >= 2
          workers[2].start_count.should >= 2

          supervisor.stop
        end
      end
    end

    context 'child restart options' do

      def worker_status(supervisor)
        worker = supervisor.instance_variable_get(:@workers).first
        return worker.thread.status
      end

      specify ':permanent restarts on abend' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :permanent)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should >= 1
      end

      specify ':permanent restarts on normal stop' do
        worker = stopper_class.new(0.1)
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :permanent)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should >= 1
      end

      specify ':temporary does not restart on abend' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :temporary)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should eq 1
      end

      specify ':temporary does not restart on normal stop' do
        worker = stopper_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :temporary)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should eq 1
      end

      specify ':temporary is deleted on abend' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :temporary)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        supervisor.size.should eq 0
      end

      specify ':temporary is deleted on normal stop' do
        worker = stopper_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :temporary)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        supervisor.size.should eq 0
      end

      specify ':transient restarts on abend' do
        worker = error_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :transient)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should >= 1
      end

      specify ':transient does not restart on normal stop' do
        worker = stopper_class.new
        supervisor = Supervisor.new(monitor_interval: 0.1)
        supervisor.add_worker(worker, restart: :transient)

        supervisor.run!
        sleep(0.5)
        supervisor.stop

        worker.start_count.should eq 1
      end
    end

    context 'supervision tree' do

      specify do
        s1 = Supervisor.new(monitor_interval: 0.1)
        s2 = Supervisor.new(monitor_interval: 0.1)
        s3 = Supervisor.new(monitor_interval: 0.1)

        workers = (1..3).collect{ sleeper_class.new }
        workers.each{|worker| s3.add_worker(worker)}

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

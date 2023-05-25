require_relative 'concern/dereferenceable_shared'
require_relative 'concern/observable_shared'
require 'concurrent/timer_task'

module Concurrent

  RSpec.describe TimerTask do

    context :dereferenceable do

      def kill_subject
        @subject.kill if defined?(@subject) && @subject
      rescue Exception
        # prevent exceptions with mocks in tests
      end

      after(:each) do
        kill_subject
      end

      def dereferenceable_subject(value, opts = {})
        kill_subject
        opts     = opts.merge(execution_interval: 0.1, run_now: true)
        @subject = TimerTask.new(opts) { value }.execute.tap { sleep(0.1) }
      end

      def dereferenceable_observable(opts = {})
        opts     = opts.merge(execution_interval: 0.1, run_now: true)
        @subject = TimerTask.new(opts) { 'value' }
      end

      def execute_dereferenceable(subject)
        subject.execute
        sleep(0.1)
      end

      it_should_behave_like :dereferenceable
    end

    context :observable do

      subject { TimerTask.new(execution_interval: 0.1) { nil } }

      after(:each) { subject.kill }

      def trigger_observable(observable)
        observable.execute
        sleep(0.2)
      end

      it_should_behave_like :observable
    end

    context 'created with #new' do

      context '#initialize' do

        it 'raises an exception if no block given' do
          expect {
            Concurrent::TimerTask.new
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not greater than zero' do
          expect {
            Concurrent::TimerTask.new(execution_interval: 0) { nil }
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not an integer' do
          expect {
            Concurrent::TimerTask.new(execution_interval: 'one') { nil }
          }.to raise_error(ArgumentError)
        end

        it 'uses the default execution interval when no interval is given' do
          subject = TimerTask.new { nil }
          expect(subject.execution_interval).to eq TimerTask::EXECUTION_INTERVAL
        end

        it 'uses the given execution interval' do
          subject = TimerTask.new(execution_interval: 5) { nil }
          expect(subject.execution_interval).to eq 5
        end

        it 'raises an exception if :interval_type is not a valid value' do
          expect {
            Concurrent::TimerTask.new(interval_type: :cat) { nil }
          }.to raise_error(ArgumentError)
        end

        it 'uses the default :interval_type when no type is given' do
          subject = TimerTask.new { nil }
          expect(subject.interval_type).to eq TimerTask::FIXED_DELAY
        end

        it 'uses the given interval type' do
          subject = TimerTask.new(interval_type: TimerTask::FIXED_RATE) { nil }
          expect(subject.interval_type).to eq TimerTask::FIXED_RATE
        end
      end

      context '#kill' do

        it 'returns true on success' do
          task = TimerTask.execute(run_now: false) { nil }
          sleep(0.1)
          expect(task.kill).to be_truthy
        end
      end

      context '#shutdown' do

        it 'returns true on success' do
          task = TimerTask.execute(run_now: false) { nil }
          sleep(0.1)
          expect(task.shutdown).to be_truthy
        end
      end
    end

    context 'arguments' do

      it 'raises an exception if no block given' do
        expect {
          Concurrent::TimerTask.execute
        }.to raise_error(ArgumentError)
      end

      specify '#execution_interval is writeable' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.new(timeout_interval: 1,
                                execution_interval: 1,
                                run_now: true) do |task|
          task.execution_interval = 3
          latch.count_down
        end

        expect(subject.execution_interval).to eq(1)
        subject.execution_interval = 0.1
        expect(subject.execution_interval).to eq(0.1)

        subject.execute
        latch.wait(0.2)

        expect(subject.execution_interval).to eq(3)
        subject.kill
      end

      it 'raises on invalid interval_type' do
        expect {
          fixed_delay = TimerTask.new(interval_type: TimerTask::FIXED_DELAY,
                        execution_interval: 0.1,
                        run_now: true) { nil }
          fixed_delay.kill
        }.not_to raise_error

        expect {
          fixed_rate = TimerTask.new(interval_type: TimerTask::FIXED_RATE,
                                  execution_interval: 0.1,
                                  run_now: true) { nil }
          fixed_rate.kill
        }.not_to raise_error

        expect {
          TimerTask.new(interval_type: :unknown,
                        execution_interval: 0.1,
                        run_now: true) { nil }
        }.to raise_error(ArgumentError)
      end

      specify '#timeout_interval being written produces a warning' do
        subject = TimerTask.new(timeout_interval: 1,
                                execution_interval: 0.1,
                                run_now: true) do |task|
          expect { task.timeout_interval = 3 }.to output("TimerTask timeouts are now ignored as these were not able to be implemented correctly\n").to_stderr
        end

        expect { subject.timeout_interval = 2 }.to output("TimerTask timeouts are now ignored as these were not able to be implemented correctly\n").to_stderr
      end
    end

    context 'execution' do

      it 'runs the block immediately when the :run_now option is true' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 500, now: true) { latch.count_down }
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is false' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 0.1, now: false) { latch.count_down }
        expect(latch.count).to eq 1
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is not given' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask.execute(execution: 0.1, now: false) { latch.count_down }
        expect(latch.count).to eq 1
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'passes a "self" reference to the block as the sole argument' do
        expected = nil
        latch    = CountDownLatch.new(1)
        subject  = TimerTask.new(execution_interval: 1, run_now: true) do |task|
          expected = task
          latch.count_down
        end
        subject.execute
        latch.wait(1)
        expect(expected).to eq subject
        expect(latch.count).to eq(0)
        subject.kill
      end

      it 'uses the global executor by default' do
        executor = Concurrent::ImmediateExecutor.new
        allow(Concurrent).to receive(:global_io_executor).and_return(executor)
        allow(executor).to receive(:post).and_call_original

        latch = CountDownLatch.new(1)
        subject = TimerTask.new(execution_interval: 0.1, run_now: true) { latch.count_down }
        subject.execute
        expect(latch.wait(1)).to be_truthy
        subject.kill

        expect(executor).to have_received(:post)
      end

      it 'uses a custom executor when given' do
        executor = Concurrent::ImmediateExecutor.new
        allow(executor).to receive(:post).and_call_original

        latch = CountDownLatch.new(1)
        subject = TimerTask.new(execution_interval: 0.1, run_now: true, executor: executor) { latch.count_down }
        subject.execute
        expect(latch.wait(1)).to be_truthy
        subject.kill

        expect(executor).to have_received(:post)
      end

      it 'uses a fixed delay when set' do
        finished = []
        latch   = CountDownLatch.new(2)
        subject = TimerTask.new(interval_type: TimerTask::FIXED_DELAY,
                                execution_interval: 0.1,
                                run_now: true) do |task|
          sleep(0.2)
          finished << Concurrent.monotonic_time
          latch.count_down
        end
        subject.execute
        latch.wait(1)
        subject.kill

        expect(latch.count).to eq(0)
        expect(finished[1] - finished[0]).to be >= 0.3
      end

      it 'uses a fixed rate when set' do
        finished = []
        latch   = CountDownLatch.new(2)
        subject = TimerTask.new(interval_type: TimerTask::FIXED_RATE,
                                execution_interval: 0.1,
                                run_now: true) do |task|
          sleep(0.2)
          finished << Concurrent.monotonic_time
          latch.count_down
        end
        subject.execute
        latch.wait(1)
        subject.kill

        expect(latch.count).to eq(0)
        expect(finished[1] - finished[0]).to be < 0.3
      end
    end

    context 'observation' do

      let(:observer) do
        Class.new do
          attr_reader :time
          attr_reader :value
          attr_reader :ex
          attr_reader :latch
          define_method(:initialize) { @latch = CountDownLatch.new(1) }
          define_method(:update) do |time, value, ex|
            @time  = time
            @value = value
            @ex    = ex
            @latch.count_down
          end
        end.new
      end

      it 'notifies all observers on success' do
        subject = TimerTask.new(execution: 0.1) { 42 }
        subject.add_observer(observer)
        subject.execute
        observer.latch.wait(1)
        expect(observer.value).to eq(42)
        expect(observer.ex).to be_nil
        subject.kill
      end

      it 'notifies all observers on error' do
        subject = TimerTask.new(execution: 0.1) { raise ArgumentError }
        subject.add_observer(observer)
        subject.execute
        observer.latch.wait(1)
        expect(observer.value).to be_nil
        expect(observer.ex).to be_a(ArgumentError)
        subject.kill
      end
    end
  end
end

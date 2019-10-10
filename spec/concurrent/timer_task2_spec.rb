require_relative 'concern/dereferenceable_shared'
require_relative 'concern/observable_shared'

module Concurrent

  RSpec.describe TimerTask2 do

    context 'created with #new' do

      context '#initialize' do

        it 'raises an exception if no block given' do
          expect {
            Concurrent::TimerTask2.new
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not greater than zero' do
          expect {
            Concurrent::TimerTask2.new(execution_interval: 0) { nil }
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :execution_interval is not an integer' do
          expect {
            Concurrent::TimerTask2.new(execution_interval: 'one') { nil }
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not greater than zero' do
          expect {
            Concurrent::TimerTask2.new(timeout_interval: 0) { nil }
          }.to raise_error(ArgumentError)
        end

        it 'raises an exception if :timeout_interval is not an integer' do
          expect {
            Concurrent::TimerTask2.new(timeout_interval: 'one') { nil }
          }.to raise_error(ArgumentError)
        end

        it 'uses the default execution interval when no interval is given' do
          subject = TimerTask2.new { nil }
          expect(subject.execution_interval).to eq TimerTask2::EXECUTION_INTERVAL
        end

        it 'uses the default timeout interval when no interval is given' do
          subject = TimerTask2.new { nil }
          expect(subject.timeout_interval).to eq TimerTask2::TIMEOUT_INTERVAL
        end

        it 'uses the given execution interval' do
          subject = TimerTask2.new(execution_interval: 5) { nil }
          expect(subject.execution_interval).to eq 5
        end

        it 'uses the given timeout interval' do
          subject = TimerTask2.new(timeout_interval: 5) { nil }
          expect(subject.timeout_interval).to eq 5
        end
      end

      context '#kill' do

        it 'returns true on success' do
          task = TimerTask2.execute(run_now: false) { nil }
          sleep(0.1)
          expect(task.kill).to be_truthy
        end
      end

      context '#shutdown' do

        it 'returns true on success' do
          task = TimerTask2.execute(run_now: false) { nil }
          sleep(0.1)
          expect(task.shutdown).to be_truthy
        end
      end

      context '#execute?' do
        it 'returns true if the task was started' do
          task = TimerTask2.new { nil }
          expect(task.execute?).to be_truthy
          task.shutdown
        end

        it 'returns false if the task was already running' do
          task = TimerTask2.new { nil }
          task.execute
          expect(task.execute?).to be_falsey
          task.shutdown
        end
      end
    end

    context 'arguments' do

      it 'raises an exception if no block given' do
        expect {
          Concurrent::TimerTask2.execute
        }.to raise_error(ArgumentError)
      end

      specify '#execution_interval is writeable' do

        latch   = CountDownLatch.new(1)
        subject = TimerTask2.new(timeout_interval: 1,
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

      specify '#timeout_interval is writeable' do

        latch   = CountDownLatch.new(1)
        subject = TimerTask2.new(timeout_interval: 1,
                                execution_interval: 0.1,
                                run_now: true) do |task|
          task.timeout_interval = 3
          latch.count_down
        end

        expect(subject.timeout_interval).to eq(1)
        subject.timeout_interval = 2
        expect(subject.timeout_interval).to eq(2)

        subject.execute
        latch.wait(0.2)

        expect(subject.timeout_interval).to eq(3)
        subject.kill
      end
    end

    context 'execution' do

      it 'runs the block immediately when the :run_now option is true' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask2.execute(execution: 500, now: true) { latch.count_down }
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is false' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask2.execute(execution: 0.1, now: false) { latch.count_down }
        expect(latch.count).to eq 1
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'waits for :execution_interval seconds when the :run_now option is not given' do
        latch   = CountDownLatch.new(1)
        subject = TimerTask2.execute(execution: 0.1, now: false) { latch.count_down }
        expect(latch.count).to eq 1
        expect(latch.wait(1)).to be_truthy
        subject.kill
      end

      it 'passes a "self" reference to the block as the sole argument' do
        expected = nil
        latch    = CountDownLatch.new(1)
        subject  = TimerTask2.new(execution_interval: 1, run_now: true) do |task|
          expected = task
          latch.count_down
        end
        subject.execute
        latch.wait(1)
        expect(expected).to eq subject
        expect(latch.count).to eq(0)
        subject.kill
      end
    end

    context 'observation' do

      it 'pushes into a channel if provided' do
        channel = Promises::Channel.new 1
        subject = TimerTask2.new(execution: 0.1, :channel => channel) { 42 }
        subject.execute
        success, value, error = channel.pop
        expect(success).to be_truthy
        expect(value).to eq(42)
        expect(error).to be_nil
        subject.kill
      end

      it 'pushes into channel on timeout' do
        channel = Promises::Channel.new 1
        subject = TimerTask2.new(run_now: true, execution: 2, timeout: 0.1, channel: channel) do |timer, cancellation|
          until cancellation.canceled?
            sleep 0.1
          end
          raise Concurrent::TimeoutError
        end
        subject.execute
        success, value, error = channel.pop
        expect(success).to be_falsy
        expect(value).to be_nil
        expect(error).to be_a(Concurrent::TimeoutError)
        subject.kill
      end

      it 'pushes into channel error' do
        channel = Promises::Channel.new 1
        subject = TimerTask2.new(execution: 0.1, channel: channel) { raise ArgumentError }
        subject.execute
        success, value, error = channel.pop
        expect(success).to be_falsy
        expect(value).to be_nil
        expect(error).to be_a(ArgumentError)
        subject.kill
      end
    end
  end
end

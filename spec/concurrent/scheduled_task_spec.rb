require 'timecop'
require_relative 'obligation_shared'
require_relative 'observable_shared'

module Concurrent

  describe ScheduledTask do
    context 'behavior' do

      # obligation

      let!(:fulfilled_value) { 10 }
      let!(:rejected_reason) { StandardError.new('mojo jojo') }

      let(:pending_subject) do
        ScheduledTask.new(1){ fulfilled_value }.execute
      end

      let(:fulfilled_subject) do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.1){ latch.count_down; fulfilled_value }.execute
        latch.wait(1)
        sleep(0.1)
        task
      end

      let(:rejected_subject) do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.1){ latch.count_down; raise rejected_reason }.execute
        latch.wait(1)
        sleep(0.1)
        task
      end

      it_should_behave_like :obligation

      # dereferenceable

      specify{ expect(ScheduledTask.ancestors).to include(Dereferenceable) }

      # observable

      subject{ ScheduledTask.new(0.1){ nil } }

      def trigger_observable(observable)
        observable.execute
        sleep(0.2)
      end

      it_should_behave_like :observable
    end

    context '#initialize' do

      it 'accepts a number of seconds (from now) as the schedule time' do
        Timecop.freeze do
          now = Time.now
          task = ScheduledTask.new(60){ nil }.execute
          expect(task.schedule_time.to_i).to eq now.to_i + 60
        end
      end

      it 'accepts a time object as the schedule time' do
        schedule = Time.now + (60*10)
        task = ScheduledTask.new(schedule){ nil }.execute
        expect(task.schedule_time).to eq schedule
      end

      it 'raises an exception when seconds is less than zero' do
        expect {
          ScheduledTask.new(-1){ nil }
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when schedule time is in the past' do
        expect {
          ScheduledTask.new(Time.now - 60){ nil }
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when no block given' do
        expect {
          ScheduledTask.new(1)
        }.to raise_error(ArgumentError)
      end

      it 'sets the initial state to :unscheduled' do
        task = ScheduledTask.new(1){ nil }
        expect(task).to be_unscheduled
      end

      it 'sets the #schedule_time to nil prior to execution' do
        task = ScheduledTask.new(1){ nil }
        expect(task.schedule_time).to be_nil
      end
    end

    context 'instance #execute' do

      it 'does nothing unless the state is :unscheduled' do
        expect(Thread).not_to receive(:new).with(any_args)
        task = ScheduledTask.new(1){ nil }
        task.instance_variable_set(:@state, :pending)
        task.execute
        task.instance_variable_set(:@state, :rejected)
        task.execute
        task.instance_variable_set(:@state, :fulfilled)
        task.execute
      end

      it 'calculates the #schedule_time on execution' do
        Timecop.freeze do
          now = Time.now
          task = ScheduledTask.new(5){ nil }
          Timecop.travel(10)
          task.execute
          expect(task.schedule_time.to_i).to eq now.to_i + 15
        end
      end

      it 'raises an exception if expected schedule time is in the past' do
        Timecop.freeze do
          schedule = Time.now + (10)
          task = ScheduledTask.new(schedule){ nil }
          Timecop.travel(60)
          expect {
            task.execute
          }.to raise_error(ArgumentError)
        end
      end

      it 'sets the sate to :pending' do
        task = ScheduledTask.new(1){ nil }
        task.execute
        expect(task).to be_pending
      end

      it 'returns self' do
        task = ScheduledTask.new(1){ nil }
        expect(task.execute).to eq task
      end
    end

    context 'class #execute' do

      it 'creates a new ScheduledTask' do
        task = ScheduledTask.execute(1){ nil }
        expect(task).to be_a(ScheduledTask)
      end

      it 'passes the block to the new ScheduledTask' do
        @expected = false
        task = ScheduledTask.execute(0.1){ @expected = true }
        task.value(1)
        expect(@expected).to be_truthy
      end

      it 'calls #execute on the new ScheduledTask' do
        task = ScheduledTask.new(0.1){ nil }
        allow(ScheduledTask).to receive(:new).with(any_args).and_return(task)
        expect(task).to receive(:execute).with(no_args)
        ScheduledTask.execute(0.1){ nil }
      end
    end

    context '#cancel' do

      it 'returns false if the task has already been performed' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.value(1)
        expect(task.cancel).to be_falsey
      end

      it 'returns false if the task is already in progress' do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.1) {
          latch.count_down
          sleep(1)
        }.execute
        latch.wait(1)
        expect(task.cancel).to be_falsey
      end

      it 'cancels the task if it has not yet scheduled' do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.1){ latch.count_down }
        task.cancel
        task.execute
        expect(latch.wait(0.3)).to be_falsey
      end


      it 'cancels the task if it has not yet started' do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.3){ latch.count_down }.execute
        sleep(0.1)
        task.cancel
        expect(latch.wait(0.5)).to be_falsey
      end

      it 'returns true on success' do
        task = ScheduledTask.new(10){ nil }.execute
        sleep(0.1)
        expect(task.cancel).to be_truthy
      end

      it 'sets the state to :cancelled when cancelled' do
        task = ScheduledTask.new(10){ 42 }.execute
        sleep(0.1)
        task.cancel
        expect(task).to be_cancelled
      end
    end

    context 'execution' do

      it 'sets the state to :in_progress when the task is running' do
        latch = Concurrent::CountDownLatch.new(1)
        task = ScheduledTask.new(0.1) {
          latch.count_down
          sleep(1)
        }.execute
        latch.wait(1)
        expect(task).to be_in_progress
      end
    end

    context 'observation' do

      let(:clazz) do
        Class.new do
          attr_reader :value
          attr_reader :reason
          attr_reader :count
          attr_reader :latch
          def initialize
            @latch = Concurrent::CountDownLatch.new(1)
          end
          def update(time, value, reason)
            @count = @count.to_i + 1
            @value = value
            @reason = reason
            @latch.count_down
          end
        end
      end

      let(:observer) { clazz.new }

      it 'returns true for an observer added while :unscheduled' do
        task = ScheduledTask.new(0.1){ 42 }
        expect(task.add_observer(observer)).to be_truthy
      end

      it 'returns true for an observer added while :pending' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        expect(task.add_observer(observer)).to be_truthy
      end

      it 'returns true for an observer added while :in_progress' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }.execute
        sleep(0.2)
        expect(task.add_observer(observer)).to be_truthy
      end

      it 'returns false for an observer added once :cancelled' do
        task = ScheduledTask.new(1){ 42 }
        task.cancel
        expect(task.add_observer(observer)).to be_falsey
      end

      it 'returns false for an observer added once :fulfilled' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.value(1)
        expect(task.add_observer(observer)).to be_falsey
      end

      it 'returns false for an observer added once :rejected' do
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        task.value(0.2)
        expect(task.add_observer(observer)).to be_falsey
      end

      it 'notifies all observers on fulfillment' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.add_observer(observer)
        observer.latch.wait(1)
        expect(observer.value).to eq(42)
        expect(observer.reason).to be_nil
      end

      it 'notifies all observers on rejection' do
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        task.add_observer(observer)
        observer.latch.wait(1)
        expect(observer.value).to be_nil
        expect(observer.reason).to be_a(StandardError)
      end

      it 'does not notify an observer added after fulfillment' do
        expect(observer).not_to receive(:update).with(any_args)
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.value(1)
        task.add_observer(observer)
        sleep(0.1)
      end

      it 'does not notify an observer added after rejection' do
        expect(observer).not_to receive(:update).with(any_args)
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        task.value(1)
        task.add_observer(observer)
        sleep(0.1)
      end

      it 'does not notify an observer added after cancellation' do
        expect(observer).not_to receive(:update).with(any_args)
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.cancel
        task.add_observer(observer)
        task.value(1)
      end
    end
  end
end

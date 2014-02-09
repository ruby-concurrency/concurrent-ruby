require 'spec_helper'
require 'timecop'
require_relative 'obligation_shared'

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
        ScheduledTask.new(0.1){ fulfilled_value }.execute.tap{ sleep(0.2) }
      end

      let(:rejected_subject) do
        ScheduledTask.new(0.1){ raise rejected_reason }.execute.tap{ sleep(0.2) }
      end

      it_should_behave_like :obligation
    end

    context '#initialize' do

      it 'accepts a number of seconds (from now) as the shcedule time' do
        Timecop.freeze do
          now = Time.now
          task = ScheduledTask.new(60){ nil }.execute
          task.schedule_time.to_i.should eq now.to_i + 60
        end
      end

      it 'accepts a time object as the schedule time' do
        schedule = Time.now + (60*10)
        task = ScheduledTask.new(schedule){ nil }.execute
        task.schedule_time.should eq schedule
      end

      it 'raises an exception when seconds is less than zero' do
        expect {
          ScheduledTask.new(-1){ nil }.execute
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when schedule time is in the past' do
        expect {
          ScheduledTask.new(Time.now - 60){ nil }.execute
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception when no block given' do
        expect {
          ScheduledTask.new(1).execute
        }.to raise_error(ArgumentError)
      end

      it 'sets the initial state to :unscheduled' do
        task = ScheduledTask.new(1){ nil }.execute
        task.should be_pending
      end
    end

    context 'instance #execute' do

      it 'does nothing unless the state is :unscheduled' do
        Thread.should_not_receive(:new).with(any_args)
        task = ScheduledTask.new(1){ nil }
        task.instance_variable_set(:@state, :pending)
        task.execute
        task.instance_variable_set(:@state, :rejected)
        task.execute
        task.instance_variable_set(:@state, :fulfilled)
        task.execute
      end

      it 'spawns a new thread when a block was given on construction' do
        Thread.should_receive(:new).with(any_args)
        task = ScheduledTask.new(1){ nil }
        task.execute
      end

      it 'sets the sate to :pending' do
        task = ScheduledTask.new(1){ nil }
        task.execute
        task.should be_pending
      end

      it 'returns self' do
        task = ScheduledTask.new(1){ nil }
        task.execute.should eq task
      end
    end

    context 'class #execute' do

      it 'creates a new ScheduledTask' do
        task = ScheduledTask.execute(1){ nil }
        task.should be_a(ScheduledTask)
      end

      it 'passes the block to the new ScheduledTask' do
        @expected = false
        task = ScheduledTask.execute(0.1){ @expected = true }
        sleep(0.2)
        @expected.should be_true
      end

      it 'calls #execute on the new ScheduledTask' do
        task = ScheduledTask.new(0.1){ nil }
        ScheduledTask.stub(:new).with(any_args).and_return(task)
        task.should_receive(:execute).with(no_args)
        ScheduledTask.execute(0.1){ nil }
      end
    end

    context '#cancel' do

      it 'returns false if the task has already been performed' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        sleep(0.2)
        task.cancel.should be_false
      end

      it 'returns false if the task is already in progress' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }.execute
        sleep(0.2)
        task.cancel.should be_false
      end

      it 'cancels the task if it has not yet started' do
        @expected = true
        task = ScheduledTask.new(0.3){ @expected = false }.execute
        sleep(0.1)
        task.cancel
        sleep(0.5)
        @expected.should be_true
      end

      it 'returns true on success' do
        task = ScheduledTask.new(0.3){ @expected = false }.execute
        sleep(0.1)
        task.cancel.should be_true
      end

      it 'sets the state to :cancelled when cancelled' do
        task = ScheduledTask.new(10){ 42 }.execute
        sleep(0.1)
        task.cancel
        task.should be_cancelled
      end
    end

    context 'execution' do

      it 'sets the state to :in_progress when the task is running' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }.execute
        sleep(0.2)
        task.should be_in_progress
      end
    end

    context 'observation' do

      let(:clazz) do
        Class.new do
          attr_reader :value
          attr_reader :reason
          attr_reader :count
          define_method(:update) do |time, value, reason|
            @count = @count.to_i + 1
            @value = value
            @reason = reason
          end
        end
      end

      let(:observer) { clazz.new }

      it 'returns true for an observer added while :pending' do
        task = ScheduledTask.new(1){ 42 }.execute
        task.add_observer(observer).should be_true
      end

      it 'returns true for an observer added while :in_progress' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }.execute
        sleep(0.2)
        task.add_observer(observer).should be_true
      end

      it 'returns true for an observer added while not running' do
        task = ScheduledTask.new(1){ 42 }.execute
        task.add_observer(observer).should be_true
      end

      it 'returns false for an observer added once :cancelled' do
        task = ScheduledTask.new(1){ 42 }.execute
        sleep(0.1)
        task.cancel
        sleep(0.1)
        task.add_observer(observer).should be_false
      end

      it 'returns false for an observer added once :fulfilled' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        sleep(0.2)
        task.add_observer(observer).should be_false
      end

      it 'returns false for an observer added once :rejected' do
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        sleep(0.2)
        task.add_observer(observer).should be_false
      end

      it 'notifies all observers on fulfillment' do
        task = ScheduledTask.new(0.1){ 42 }.execute
        task.add_observer(observer)
        sleep(0.2)
        task.value.should == 42
        task.reason.should be_nil
        observer.value.should == 42
        observer.reason.should be_nil
      end

      it 'notifies all observers on rejection' do
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        task.add_observer(observer)
        sleep(0.2)
        task.value.should be_nil
        task.reason.should be_a(StandardError)
        observer.value.should be_nil
        observer.reason.should be_a(StandardError)
      end

      it 'does not notify an observer added after fulfillment' do
        observer.should_not_receive(:update).with(any_args())
        task = ScheduledTask.new(0.1){ 42 }.execute
        sleep(0.2)
        task.add_observer(observer)
        sleep(0.1)
      end

      it 'does not notify an observer added after rejection' do
        observer.should_not_receive(:update).with(any_args())
        task = ScheduledTask.new(0.1){ raise StandardError }.execute
        sleep(0.2)
        task.add_observer(observer)
        sleep(0.1)
      end

      it 'does not notify an observer added after cancellation' do
        observer.should_not_receive(:update).with(any_args())
        task = ScheduledTask.new(0.5){ 42 }.execute
        sleep(0.1)
        task.cancel
        sleep(0.1)
        task.add_observer(observer)
        sleep(0.5)
      end
    end
  end
end

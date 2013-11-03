require 'spec_helper'
require 'timecop'
require_relative 'obligation_shared'
require_relative 'runnable_shared'

module Concurrent

  describe ScheduledTask do

    context 'behavior' do

      # runnable

      subject { ScheduledTask.new(0.5){ nil } }
      it_should_behave_like :runnable

      # obligation

      let!(:fulfilled_value) { 10 }
      let!(:rejected_reason) { StandardError.new('mojo jojo') }

      let(:pending_subject) do
        task = ScheduledTask.new(1){ fulfilled_value }
        task.run!
        task
      end

      let(:fulfilled_subject) do
        task = ScheduledTask.new(0.1){ fulfilled_value }
        task.run
        task
      end

      let(:rejected_subject) do
        task = ScheduledTask.new(0.1){ raise rejected_reason }
        task.run
        task
      end

      it_should_behave_like :obligation
    end

    context '#initialize' do

      it 'accepts a number of seconds (from now) as the shcedule time' do
        Timecop.freeze do
          now = Time.now
          task = ScheduledTask.new(60){ nil }
          task.schedule_time.to_i.should eq now.to_i + 60
        end
      end

      it 'accepts a time object as the schedule time' do
        schedule = Time.now + (60*10)
        task = ScheduledTask.new(schedule){ nil }
        task.schedule_time.should eq schedule
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

      it 'sets the initial state to :pending' do
        task = ScheduledTask.new(1){ nil }
        task.should be_pending
      end
    end

    context '#cancel' do

      it 'returns false if the task has already been performed' do
        task = ScheduledTask.new(0.1){ 42 }
        task.run!
        sleep(0.2)
        task.cancel.should be_false
      end

      it 'returns false if the task is already in progress' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }
        task.run!
        sleep(0.2)
        task.cancel.should be_false
      end

      it 'cancels the task if it has not yet started' do
        @expected = true
        task = ScheduledTask.new(0.3){ @expected = false }
        task.run!
        sleep(0.1)
        task.cancel
        sleep(0.5)
        @expected.should be_true
      end

      it 'returns true on success' do
        task = ScheduledTask.new(0.3){ @expected = false }
        task.run!
        sleep(0.1)
        task.cancel.should be_true
      end

      it 'sets the state to :cancelled when cancelled' do
        task = ScheduledTask.new(10){ 42 }
        task.run!
        sleep(0.1)
        task.cancel
        task.should be_cancelled
      end

      it 'stops the runnable' do
        task = ScheduledTask.new(0.2){ 42 }
        task.run!
        sleep(0.1)
        task.cancel
        sleep(0.2)
        task.should_not be_running
      end
    end

    context 'execution' do

      it 'sets the state to :in_progress when the task is running' do
        task = ScheduledTask.new(0.1){ sleep(1); 42 }
        task.run!
        sleep(0.2)
        task.should be_in_progress
      end

      it 'stops itself on task completion' do
        task = ScheduledTask.new(0.1){ 42 }
        task.run!
        sleep(0.2)
        task.should_not be_running
      end
    end
  end
end

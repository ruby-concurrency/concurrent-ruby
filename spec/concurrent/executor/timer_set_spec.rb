require 'spec_helper'

module Concurrent

  describe TimerSet do

    subject{ TimerSet.new(executor: ImmediateExecutor.new) }

    after(:each){ subject.kill }

    it 'uses the executor given at construction' do
      executor = double(:executor)
      executor.should_receive(:post).with(no_args)
      subject = TimerSet.new(executor: executor)
      subject.post(0){ nil }
      sleep(0.1)
    end

    it 'uses the global task pool be default' do
      Concurrent.configuration.global_task_pool.should_receive(:post).with(no_args)
      subject = TimerSet.new
      subject.post(0){ nil }
      sleep(0.1)
    end

    it 'executes a given task when given a Time' do
      expected = false
      subject.post(Time.now + 0.1){ expected = true }
      sleep(0.2)
      expected.should be_true
    end

    it 'executes a given task when given an interval in seconds' do
      expected = false
      subject.post(0.1){ expected = true }
      sleep(0.2)
    end

    it 'immediately posts a task when the delay is zero' do
      Thread.should_not_receive(:new).with(any_args)
      expected = false
      subject.post(0){ expected = true }
    end

    it 'does not execute tasks early' do
      expected = AtomicFixnum.new(0)
      subject.post(0.2){ expected.increment }
      sleep(0.1)
      expected.value.should eq 0
      sleep(0.1)
      expected.value.should eq 1
    end

    it 'raises an exception when given a task with a past Time value' do
      expect {
        subject.post(Time.now - 10){ nil }
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception when given a task with a delay less than zero' do
      expect {
        subject.post(-10){ nil }
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception when no block given' do
      expect {
        subject.post(10)
      }.to raise_error(ArgumentError)
    end

    it 'executes all tasks scheduled for the same time' do
      expected = AtomicFixnum.new(0)
      5.times{ subject.post(0.1){ expected.increment } }
      sleep(0.2)
      expected.value.should eq 5
    end

    it 'executes tasks with different times in schedule order' do
      expected = []
      3.times{|i| subject.post(i/10){ expected << i } }
      sleep(0.3)
      expected.should eq [0, 1, 2]
    end

    it 'cancels all pending tasks on #shutdown' do
      expected = AtomicFixnum.new(0)
      10.times{ subject.post(0.2){ expected.increment } }
      sleep(0.1)
      subject.shutdown
      sleep(0.2)
      expected.value.should eq 0
    end

    it 'cancels all pending tasks on #kill' do
      expected = AtomicFixnum.new(0)
      10.times{ subject.post(0.2){ expected.increment } }
      sleep(0.1)
      subject.kill
      sleep(0.2)
      expected.value.should eq 0
    end

    it 'stops the monitor thread on #shutdown' do
      subject.post(0.1){ nil } # start the monitor thread
      sleep(0.2)
      subject.instance_variable_get(:@thread).should_not be_nil
      subject.shutdown
      sleep(0.1)
      subject.instance_variable_get(:@thread).should_not be_alive
    end

    it 'kills the monitor thread on #kill' do
      subject.post(0.1){ nil } # start the monitor thread
      sleep(0.2)
      subject.instance_variable_get(:@thread).should_not be_nil
      subject.kill
      sleep(0.1)
      subject.instance_variable_get(:@thread).should_not be_alive
    end

    it 'rejects tasks once shutdown' do
      expected = AtomicFixnum.new(0)
      subject.shutdown
      sleep(0.1)
      subject.post(0){ expected.increment }.should be_false
      sleep(0.1)
      expected.value.should eq 0
    end

    it 'rejects tasks once killed' do
      expected = AtomicFixnum.new(0)
      subject.kill
      sleep(0.1)
      subject.post(0){ expected.increment }.should be_false
      sleep(0.1)
      expected.value.should eq 0
    end

    it 'is running? when first created' do
      subject.should be_running
      subject.should_not be_shutdown
    end

    it 'is running? after tasks have been post' do
      subject.post(0.1){ nil }
      subject.should be_running
      subject.should_not be_shutdown
    end

    it 'is shutdown? after shutdown completes' do
      subject.shutdown
      sleep(0.1)
      subject.should_not be_running
      subject.should be_shutdown
    end

    it 'is shutdown? after being killed' do
      subject.kill
      sleep(0.1)
      subject.should_not be_running
      subject.should be_shutdown
    end

    specify '#wait_for_termination returns true if shutdown completes before timeout' do
      subject.post(0.1){ nil }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(0.1).should be_true
    end

    specify '#wait_for_termination returns false on timeout' do
      subject.post(0.1){ nil }
      sleep(0.1)
      # do not call shutdown -- force timeout
      subject.wait_for_termination(0.1).should be_false
    end
  end
end

require 'spec_helper'

share_examples_for :runnable do

  after(:each) do
    subject.stop
    @thread.kill unless @thread.nil?
  end

  context '#run' do

    it 'starts the (blocking) runner on the current thread when stopped' do
      @thread = Thread.new { subject.run }
      @thread.join(1).should be_nil
    end

    it 'raises an exception when already running' do
      @thread = Thread.new { subject.run }
      sleep(0.1)
      expect {
        subject.run
      }.to raise_error
    end

    it 'returns true when stopped normally' do
      @expected = false
      @thread = Thread.new { @expected = subject.run }
      sleep(0.1)
      subject.stop
      sleep(0.1)
      @expected.should be_true
    end

    it 'returns false when the task loop raises an exception' do
      @expected = false
      subject.stub(:on_task).and_raise(StandardError)
      @thread = Thread.new { @expected = subject.run }
      sleep(0.1)
      @expected.should be_false
    end
  end

  context '#stop' do

    it 'returns true when not running' do
      subject.stop.should be_true
    end

    it 'returns true when successfully stopped' do
      @thread = Thread.new { subject.run }
      sleep(0.1)
      subject.stop.should be_true
      subject.should_not be_running
    end
  end

  context '#running?' do

    it 'returns true when running' do
      @thread = Thread.new { subject.run }
      sleep(0.1)
      subject.should be_running
    end

    it 'returns false when not running' do
      subject.should_not be_running
    end

    it 'returns false if runner abends' do
      subject.stub(:on_task).and_raise(StandardError)
      @thread = Thread.new { subject.run }
      sleep(0.1)
      subject.should_not be_running
    end
  end
end

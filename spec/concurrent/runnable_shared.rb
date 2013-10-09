require 'spec_helper'

share_examples_for :runnable do

  after(:each) do
    subject.stop
    @thread.kill unless @thread.nil?
    sleep(0.1)
  end

  context '#run' do

    it 'starts the (blocking) runner on the current thread when stopped' do
      @thread = Thread.new { subject.run }
      @thread.join(1).should be_nil
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

    it 'returns false when not running' do
      subject.should_not be_running
    end
  end
end

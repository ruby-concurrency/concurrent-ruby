require 'spec_helper'

share_examples_for 'synchronous demultiplexer' do

  context '#initialize' do

    it 'sets the initial state to :stopped' do
      subject.should be_stopped
    end
  end

  context '#start' do

    it 'raises an exception if already started' do
      subject.start

      lambda {
        subject.start
      }.should raise_error(StandardError)
    end

    it 'returns true on success' do
    end

    it 'returns false on failure' do
    end
  end

  context '#stop' do
  end

  context '#stopped?' do

    it 'returns true when stopped' do
      subject.start
      sleep(0.1)
      subject.stop
      sleep(0.1)
      subject.should be_stopped
    end

    it 'returns false when running' do
      subject.start
      sleep(0.1)
      subject.should_not be_stopped
    end
  end

  context '#accept' do

    it 'returns a correct EventContext object' do
    end

    it 'returns nil on exception' do
    end
  end

  context '#respond' do
  end
end

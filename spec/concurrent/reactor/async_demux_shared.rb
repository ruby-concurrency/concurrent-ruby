require 'spec_helper'

share_examples_for 'asynchronous demultiplexer' do

  context 'start' do

    it 'raises an exception if already started' do
      subject.start

      lambda {
        subject.start
      }.should raise_error(StandardError)
    end

    it 'sets the initial state to :stopped' do
      subject.should be_stopped
    end
  end

  context '#set_reactor' do

    it 'raises an exception when given an invalid reactor' do
      lambda {
        subject.set_reactor(Concurrent::Reactor.new)
      }.should_not raise_error

      lambda {
        subject.set_reactor('bogus')
      }.should raise_error(ArgumentError)
    end
  end

  context 'stop' do
  end

  context 'stopped?' do

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

  context 'event handling' do

    it 'should post events to the reactor' do
      demux = subject
      reactor = Concurrent::Reactor.new(demux)
      reactor.add_handler(:foo){ nil }
      reactor.should_receive(:handle).with(:foo, 1,2,3).and_return([:ok, nil])

      Thread.new { reactor.start }
      sleep(0.1)

      post_event(demux, :foo, 1, 2, 3)

      reactor.stop
      sleep(0.1)
    end
  end
end

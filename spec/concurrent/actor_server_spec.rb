require 'spec_helper'

describe Concurrent::ActorServer do

  subject { Concurrent::ActorServer.new }

  context '#running?' do
    it 'returns true when the drb server is running' do
      subject.should be_running
    end

    it 'returns false when drb server is not running' do
      subject.stop
      subject.should_not be_running
    end
  end

  context '#stop' do

    its(:running?) { should be_true }

    it 'stops the drb server' do
      subject.stop
      subject.should_not be_running
    end
  end

  context '#start' do

    before { subject.stop }

    its(:running?) { should be_false }

    it 'starts the drb server' do
      subject.start
      subject.should be_running
    end
  end
end

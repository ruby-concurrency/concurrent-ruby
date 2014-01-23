require 'spec_helper'

describe Concurrent::ActorServer do

  subject { Concurrent::ActorServer.new(host: 'localhost', port: 8787) }

  context '#running?' do

    it 'returns true when the drb server is running' do
      subject.should be_running
    end

    it 'returns false when drb server is not running' do
      subject.stop
      subject.should_not be_running
    end

  end



end

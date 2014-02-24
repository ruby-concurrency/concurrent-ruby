require 'spec_helper'

describe Concurrent::ActorServer do

  subject { Concurrent::ActorServer.new }
  before  { subject.run! }

  class MyActor; end

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

  context '#run!' do

    before { subject.stop }

    its(:running?) { should be_false }

    it 'starts the drb server' do
      subject.run!
      subject.should be_running
    end
  end

  context '#pool' do

    it 'sets the default pool size to one' do
      subject.pool('foo', MyActor)
      subject.instance_variable_get('@actor_pool')['foo'].size.should == 1
    end

    it 'sets the pool size with a specific size' do
      subject.pool('foo', MyActor, 10)
      subject.instance_variable_get('@actor_pool')['foo'].size.should == 10
    end
  end
end

require 'spec_helper'

describe Concurrent::ActorServer do

  subject { Concurrent::ActorServer.new }
  before  { subject.run! }

  class MyActor < Concurrent::Actor; end

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

    it 'creates a poolbox instance' do
      subject.pool('foo', MyActor, 10)
      subject.actor_pool['foo'][:actors].should be_instance_of Concurrent::Actor::Poolbox
    end


    it 'sets the default pool size to one' do
      MyActor.should_receive(:pool).with(1).and_return([[], []])
      subject.pool('foo', MyActor)
    end

    it 'sets the pool size with a specific size' do
      MyActor.should_receive(:pool).with(10).and_return([[], []])
      subject.pool('foo', MyActor, 10)
    end
  end
end

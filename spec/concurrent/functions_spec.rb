require 'spec_helper'

module Concurrent

  describe Agent do

    it 'aliases #<< for Agent#post' do
      subject = Agent.new(0)
      subject << proc{ 100 }
      sleep(0.1)
      subject.value.should eq 100
    end

    it 'aliases Kernel#agent for Agent.new' do
      agent(10).should be_a(Agent)
    end

    it 'aliases Kernel#deref for #deref' do
      deref(Agent.new(10)).should eq 10
      deref(Agent.new(10), 10).should eq 10
    end

    it 'aliases Kernel:post for Agent#post' do
      subject = Agent.new(0)
      post(subject){ 100 }
      sleep(0.1)
      subject.value.should eq 100
    end
  end

  describe Defer do

    it 'aliases Kernel#defer' do
      defer{ nil }.should be_a(Defer)
    end
  end

  describe Future do

    it 'aliases Kernel#future for Future.new' do
      future().should be_a(Future)
      future(){ nil }.should be_a(Future)
      future(1, 2, 3).should be_a(Future)
      future(1, 2, 3){ nil }.should be_a(Future)
    end
  end

  describe Promise do

    it 'aliases Kernel#promise for Promise.new' do
      promise().should be_a(Promise)
      promise(){ nil }.should be_a(Promise)
      promise(1, 2, 3).should be_a(Promise)
      promise(1, 2, 3){ nil }.should be_a(Promise)
    end
  end
end

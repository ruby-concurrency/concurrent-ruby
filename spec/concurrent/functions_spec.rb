require 'spec_helper'

module Concurrent

  describe 'functions' do

    context '#post' do

      it 'calls #post when supported by the object' do
        object = Class.new{
          def post() nil; end
        }.new
        object.should_receive(:post).with(no_args())
        post(object){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          post(object){ nil }
        }.should raise_error(ArgumentError)
      end
    end

    context '#deref' do

      it 'returns the value of the #deref function' do
        object = Class.new{
          def deref() nil; end
        }.new
        object.should_receive(:deref).with(nil)
        deref(object, nil){ nil }
      end

      it 'returns the value of the #value function' do
        object = Class.new{
          def value() nil; end
        }.new
        object.should_receive(:value).with(nil)
        deref(object, nil){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          deref(object, nil){ nil }
        }.should raise_error(ArgumentError)
      end
    end

    context '#pending?' do

      it 'returns the value of the #pending? function' do
        object = Class.new{
          def pending?() nil; end
        }.new
        object.should_receive(:pending?).with(no_args())
        pending?(object){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          pending?(object){ nil }
        }.should raise_error(ArgumentError)
      end
    end

    context '#fulfilled?' do

      it 'returns the value of the #fulfilled? function' do
        object = Class.new{
          def fulfilled?() nil; end
        }.new
        object.should_receive(:fulfilled?).with(no_args())
        fulfilled?(object){ nil }
      end

      it 'returns the value of the #realized? function' do
        object = Class.new{
          def realized?() nil; end
        }.new
        object.should_receive(:realized?).with(no_args())
        fulfilled?(object){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          fulfilled?(object){ nil }
        }.should raise_error(ArgumentError)
      end
    end

    context '#realized?' do

      it 'returns the value of the #realized? function' do
        object = Class.new{
          def realized?() nil; end
        }.new
        object.should_receive(:realized?).with(no_args())
        realized?(object){ nil }
      end

      it 'returns the value of the #fulfilled? function' do
        object = Class.new{
          def fulfilled?() nil; end
        }.new
        object.should_receive(:fulfilled?).with(no_args())
        realized?(object){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          realized?(object){ nil }
        }.should raise_error(ArgumentError)
      end
    end

    context '#rejected?' do

      it 'returns the value of the #rejected? function' do
        object = Class.new{
          def rejected?() nil; end
        }.new
        object.should_receive(:rejected?).with(no_args())
        rejected?(object){ nil }
      end

      it 'raises an exception when not supported by the object' do
        object = Class.new{ }.new
        lambda {
          rejected?(object){ nil }
        }.should raise_error(ArgumentError)
      end
    end
  end

  describe Agent do

    before(:each) do
      Agent.thread_pool = FixedThreadPool.new(1)
    end

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

    before(:each) do
      Defer.thread_pool = FixedThreadPool.new(1)
    end

    it 'aliases Kernel#defer' do
      defer{ nil }.should be_a(Defer)
    end
  end

  describe Executor do

    it 'aliases Kernel#executor' do
      ex = executor('executor'){ nil }
      ex.should be_a(Executor::ExecutionContext)
      ex.kill
    end
  end

  describe Future do

    before(:each) do
      Future.thread_pool = FixedThreadPool.new(1)
    end

    it 'aliases Kernel#future for Future.new' do
      future().should be_a(Future)
      future(){ nil }.should be_a(Future)
      future(1, 2, 3).should be_a(Future)
      future(1, 2, 3){ nil }.should be_a(Future)
    end
  end

  describe Promise do

    before(:each) do
      Promise.thread_pool = FixedThreadPool.new(1)
    end

    it 'aliases Kernel#promise for Promise.new' do
      promise().should be_a(Promise)
      promise(){ nil }.should be_a(Promise)
      promise(1, 2, 3).should be_a(Promise)
      promise(1, 2, 3){ nil }.should be_a(Promise)
    end
  end
end

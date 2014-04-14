require 'spec_helper'
require_relative 'actor_ref_shared'

module Concurrent

  describe SimpleActorRef do

    after(:each) do
      subject.shutdown
      sleep(0.1)
    end

    subject do
      create_actor_test_class.spawn
    end

    it_should_behave_like :actor_ref

    context 'construction' do

      it 'supports :args being nil' do
        subject = create_actor_test_class.spawn
        actor = subject.instance_variable_get(:@actor)
        actor.argv.should be_empty
      end

      it 'passes all :args option to the actor constructor' do
        subject = create_actor_test_class.spawn(args: [1, 2, 3, 4])
        actor = subject.instance_variable_get(:@actor)
        actor.argv.should eq [1, 2, 3, 4]
      end

      it 'passes the options hash to the ActorRef constructor' do
        subject # prevent the after(:all) block from breaking this test
        opts = {foo: :bar, hello: :world}
        described_class.should_receive(:new).once.with(anything, opts)
        create_actor_test_class.spawn(opts)
      end

      it 'calls #on_start on the actor' do
        actor = double(:create_actor_test_class)
        actor.should_receive(:on_start).once.with(no_args)
        SimpleActorRef.new(actor)
      end
    end

    context 'reset_on_error' do

      it 'creates a new actor on exception when true' do
        clazz = create_actor_test_class
        args = [:foo, :bar, :hello, :world]
        ref = clazz.spawn(reset_on_error: true, args: args)
        clazz.should_receive(:new).once.with(*args)
        ref.post(:poison)
      end

      it 'does not create a new actor on exception when false' do
        clazz = create_actor_test_class
        args = [:foo, :bar, :hello, :world]
        ref = clazz.spawn(reset_on_error: true, args: args)
        clazz.should_not_receive(:new).with(any_args)
        ref.post(:poison)
      end

      it 'defaults to false' do
        clazz = create_actor_test_class
        args = [:foo, :bar, :hello, :world]
        ref = clazz.spawn(args: args)
        clazz.should_not_receive(:new).with(any_args)
        ref.post(:poison)
      end
    end

    context 'rescue_exception' do

      after(:each) do
        @ref.shutdown if @ref
      end

      it 'rescues Exception in the actor thread when true' do
        @ref = create_actor_test_class.spawn(
          abort_on_exception: false,
          rescue_exception: true
        )

        ivar = @ref.post(:poison)
        sleep(0.1)
        ivar.reason.should be_a StandardError

        ivar = @ref.post(:bullet)
        sleep(0.1)
        ivar.reason.should be_a Exception
      end

      it 'rescues StandardError in the actor thread when false' do
        @ref = create_actor_test_class.spawn(
          abort_on_exception: false,
          rescue_exception: false
        )

        ivar = @ref.post(:poison)
        sleep(0.1)
        ivar.reason.should be_a StandardError

        ivar = @ref.post(:bullet)
        sleep(0.1)
        ivar.reason.should be_nil
      end

      it 'defaults to false' do
        @ref = create_actor_test_class.spawn(abort_on_exception: false)

        ivar = @ref.post(:poison)
        sleep(0.1)
        ivar.reason.should be_a StandardError

        ivar = @ref.post(:bullet)
        sleep(0.1)
        ivar.reason.should be_nil
      end
    end

    context '#shutdown' do

      it 'calls #on_shutdown when shutdown' do
        actor = subject.instance_variable_get(:@actor)
        actor.should_receive(:on_shutdown).once.with(no_args)
        subject << :foo
        sleep(0.1)

        subject.shutdown
      end
    end
  end
end

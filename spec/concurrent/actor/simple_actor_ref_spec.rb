require 'spec_helper'
require_relative 'actor_ref_shared'

module Concurrent

  describe SimpleActorRef do

    after(:each) do
      subject.shutdown
      sleep(0.1)
    end

    subject do
      shared_actor_test_class.spawn
    end

    it_should_behave_like :actor_ref

    context 'construction' do

      it 'supports :args being nil' do
        subject = shared_actor_test_class.spawn
        actor = subject.instance_variable_get(:@actor)
        actor.argv.should be_empty
      end

      it 'passes all :args option to the actor constructor' do
        subject = shared_actor_test_class.spawn(args: [1, 2, 3, 4])
        actor = subject.instance_variable_get(:@actor)
        actor.argv.should eq [1, 2, 3, 4]
      end

      it 'passes the options hash to the ActorRef constructor' do
        subject # prevent the after(:all) block from breaking this test
        opts = {foo: :bar, hello: :world}
        described_class.should_receive(:new).once.with(anything, opts)
        shared_actor_test_class.spawn(opts)
      end

      it 'calls #on_start on the actor' do
        actor = double(:shared_actor_test_class)
        actor.should_receive(:on_start).once.with(no_args)
        SimpleActorRef.new(actor)
      end
    end

    context 'reset_on_error' do

      after(:each) do
        @ref.shutdown if @ref
      end

      it 'causes #on_reset to be called on exception when true' do
        @ref = shared_actor_test_class.spawn(reset_on_error: true)
        actor = @ref.instance_variable_get(:@actor)
        actor.should_receive(:on_reset).once.with(no_args)
        @ref << :poison
        sleep(0.1)
      end

      it 'prevents #on_reset form being called on exception when false' do
        @ref = shared_actor_test_class.spawn(reset_on_error: false)
        actor = @ref.instance_variable_get(:@actor)
        actor.should_not_receive(:on_reset).with(any_args)
        @ref << :poison
        sleep(0.1)
      end

      it 'defaults to true' do
        @ref = shared_actor_test_class.spawn
        actor = @ref.instance_variable_get(:@actor)
        actor.should_receive(:on_reset).once.with(no_args)
        @ref << :poison
        sleep(0.1)
      end
    end

    context 'rescue_exception' do

      after(:each) do
        @ref.shutdown if @ref
      end

      it 'rescues Exception in the actor thread when true' do
        @ref = shared_actor_test_class.spawn(
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
        @ref = shared_actor_test_class.spawn(
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
        @ref = shared_actor_test_class.spawn(abort_on_exception: false)

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

require 'spec_helper'
require_relative 'obligation_shared'

module Concurrent

  describe Future do

    let!(:fulfilled_value) { 10 }
    let!(:rejected_reason) { StandardError.new('mojo jojo') }

    let(:pending_subject) do
      Future.new{ sleep(2) }
    end

    let(:fulfilled_subject) do
      Future.new{ fulfilled_value }.tap(){ sleep(0.1) }
    end

    let(:rejected_subject) do
      Future.new{ raise rejected_reason }.tap(){ sleep(0.1) }
    end

    before(:each) do
      Future.thread_pool = FixedThreadPool.new(1)
    end

    it_should_behave_like Obligation

    context 'behavior' do

      it 'implements :future behavior' do
        lambda {
          Future.new{ nil }
        }.should_not raise_error

        Future.new{ nil }.behaves_as?(:future).should be_true
      end
    end

    context '#initialize' do

      it 'spawns a new thread when a block is given' do
        Future.thread_pool.should_receive(:post).once.with(any_args())
        Future.new{ nil }
      end

      it 'does not spawns a new thread when no block given' do
        Thread.should_not_receive(:new).with(any_args())
        Future.new
      end

      it 'immediately sets the state to :fulfilled when no block given' do
        Future.new.should be_fulfilled
      end

      it 'immediately sets the value to nil when no block given' do
        Future.new.value.should be_nil
      end
    end

    context 'fulfillment' do

      it 'passes all arguments to handler' do
        @a = @b = @c = nil
        f = Future.new(1, 2, 3) do |a, b, c|
          @a, @b, @c = a, b, c
        end
        sleep(0.1)
        [@a, @b, @c].should eq [1, 2, 3]
      end

      it 'sets the value to the result of the handler' do
        f = Future.new(10){|a| a * 2 }
        sleep(0.1)
        f.value.should eq 20
      end

      it 'sets the state to :fulfilled when the block completes' do
        f = Future.new(10){|a| a * 2 }
        sleep(0.1)
        f.should be_fulfilled
      end

      it 'sets the value to nil when the handler raises an exception' do
        f = Future.new{ raise StandardError }
        sleep(0.1)
        f.value.should be_nil
      end

      it 'sets the state to :rejected when the handler raises an exception' do
        f = Future.new{ raise StandardError }
        sleep(0.1)
        f.should be_rejected
      end

      context 'aliases' do

        it 'aliases #realized? for #fulfilled?' do
          fulfilled_subject.should be_realized
        end

        it 'aliases #deref for #value' do
          fulfilled_subject.deref.should eq fulfilled_value
        end
      end
    end
  end
end

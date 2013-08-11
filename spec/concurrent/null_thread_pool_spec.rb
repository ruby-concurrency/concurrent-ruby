require 'spec_helper'

require 'concurrent/goroutine'

module Concurrent

  describe NullThreadPool do

    subject { NullThreadPool.new }

    after(:all) do
      $GLOBAL_THREAD_POOL = FixedThreadPool.new(1)
    end

    context '#post' do

      it 'proxies a call without arguments' do
        Thread.should_receive(:new).with(no_args())
        $GLOBAL_THREAD_POOL.should_not_receive(:post).with(any_args())
        subject.post{ nil }
      end

      it 'proxies a call with arguments' do
        Thread.should_receive(:new).with(1,2,3)
        $GLOBAL_THREAD_POOL.should_not_receive(:post).with(any_args())
        subject.post(1,2,3){ nil }
      end

      it 'aliases #<<' do
        Thread.should_receive(:new).with(no_args())
        $GLOBAL_THREAD_POOL.should_not_receive(:post).with(any_args())
        subject << proc{ nil }
      end
    end

    context 'operation' do

      context 'goroutine' do

        it 'gets a new thread' do
          $GLOBAL_THREAD_POOL = subject

          t = Thread.new{ nil }

          Thread.should_receive(:new).with(no_args()).and_return(t)
          go{ nil }

          Thread.should_receive(:new).with(1,2,3).and_return(t)
          go(1,2,3){ nil }
        end
      end
    end
  end
end

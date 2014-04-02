require 'spec_helper'

if jruby?

  require_relative 'cached_thread_pool_shared'

  module Concurrent

    describe JavaCachedThreadPool do

      subject { described_class.new(max_threads: 5, overflow_policy: :discard) }

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      it_should_behave_like :cached_thread_pool

      it 'defines an #at_exit shutdown hook'

      context '#initialize' do

        it 'sets :min_length correctly' do
          subject = JavaCachedThreadPool.new
          subject.min_length.should eq 0
        end

        it 'sets :max_length correctly' do
          subject = JavaCachedThreadPool.new(max_threads: 5)
          subject.max_length.should eq 5
        end

        it 'sets :idletime correctly' do
          subject = JavaCachedThreadPool.new(idletime: 10)
          subject.idletime.should eq 10
        end

        it 'sets :max_queue correctly' do
          subject = JavaCachedThreadPool.new
          subject.max_queue.should eq 0
        end

        it 'sets :overflow_policy correctly' do
          clazz = java.util.concurrent.ThreadPoolExecutor::DiscardPolicy
          policy = clazz.new
          clazz.should_receive(:new).at_least(:once).with(any_args).and_return(policy)

          subject = JavaCachedThreadPool.new(overflow_policy: :discard)
          subject.overflow_policy.should eq :discard
        end

        it 'defaults :overflow_policy to :abort' do
          subject = JavaCachedThreadPool.new
          subject.overflow_policy.should eq :abort
        end

        it 'raises an exception if given an invalid :overflow_policy' do
          expect {
            JavaCachedThreadPool.new(overflow_policy: :bogus)
          }.to raise_error(ArgumentError)
        end
      end
    end
  end
end

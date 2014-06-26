require 'spec_helper'

if Concurrent::TestHelpers.jruby?

  require_relative 'cached_thread_pool_shared'

  module Concurrent

    describe JavaCachedThreadPool, :type=>:jruby do

      subject { described_class.new(overflow_policy: :discard) }

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      it_should_behave_like :cached_thread_pool

      context '#initialize' do

        it 'sets :overflow_policy correctly' do
          clazz = java.util.concurrent.ThreadPoolExecutor::DiscardPolicy
          policy = clazz.new
          expect(clazz).to receive(:new).at_least(:once).with(any_args).and_return(policy)

          subject = JavaCachedThreadPool.new(overflow_policy: :discard)
          expect(subject.overflow_policy).to eq :discard
        end

        it 'defaults :overflow_policy to :abort' do
          subject = JavaCachedThreadPool.new
          expect(subject.overflow_policy).to eq :abort
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

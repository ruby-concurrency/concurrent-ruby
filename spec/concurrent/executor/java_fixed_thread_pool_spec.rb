require 'spec_helper'

if Concurrent::TestHelpers.jruby?

  require_relative 'fixed_thread_pool_shared'

  module Concurrent

    describe JavaFixedThreadPool, :type=>:jruby do

      subject { described_class.new(5, overflow_policy: :discard) }

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      it_should_behave_like :fixed_thread_pool

      context '#initialize' do


        it 'sets :overflow_policy correctly' do
          clazz  = java.util.concurrent.ThreadPoolExecutor::DiscardPolicy
          policy = clazz.new
          clazz.should_receive(:new).at_least(:once).with(any_args).and_return(policy)

          subject = JavaFixedThreadPool.new(5, overflow_policy: :discard)
          subject.overflow_policy.should eq :discard
        end

      end
    end
  end
end

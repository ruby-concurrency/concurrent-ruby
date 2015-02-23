if Concurrent::TestHelpers.jruby?

  require_relative 'fixed_thread_pool_shared'

  module Concurrent

    describe JavaFixedThreadPool, :type=>:jruby do

      subject { described_class.new(5, fallback_policy: :discard) }

      after(:each) do
        subject.kill
        sleep(0.1)
      end

      it_should_behave_like :fixed_thread_pool

      context '#initialize' do


        it 'sets :fallback_policy correctly' do
          clazz  = java.util.concurrent.ThreadPoolExecutor::DiscardPolicy
          policy = clazz.new
          expect(clazz).to receive(:new).at_least(:once).with(any_args).and_return(policy)

          subject = JavaFixedThreadPool.new(5, fallback_policy: :discard)
          expect(subject.fallback_policy).to eq :discard
        end

      end
    end
  end
end

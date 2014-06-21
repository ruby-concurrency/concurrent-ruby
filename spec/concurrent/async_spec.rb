require 'spec_helper'

module Concurrent

  describe Async do

    let(:executor) { PerThreadExecutor.new }

    let(:async_class) do
      Class.new do
        include Concurrent::Async
        attr_accessor :accessor
        def initialize
          init_mutex
        end
        def echo(msg)
          msg
        end
        def gather(first, second = nil)
          return first, second
        end
        def boom(ex = StandardError.new)
          raise ex
        end
        def wait(seconds)
          sleep(seconds)
        end
        def with_block
          yield
        end
      end
    end

    subject do
      obj = async_class.new
      obj.executor = executor
      obj
    end

    context '#validate_argc' do

      subject do
        Class.new {
          def zero() nil; end
          def three(a, b, c, &block) nil; end
          def two_plus_two(a, b, c=nil, d=nil, &block) nil; end
          def many(*args, &block) nil; end
        }.new
      end

      it 'raises an exception when the method is not defined' do
        expect {
          Async::validate_argc(subject, :bogus)
        }.to raise_error(StandardError)
      end

      it 'raises an exception for too many args on a zero arity method' do
        expect {
          Async::validate_argc(subject, :zero, 1, 2, 3)
        }.to raise_error(ArgumentError)
      end

      it 'does not raise an exception for correct zero arity' do
        expect {
          Async::validate_argc(subject, :zero)
        }.not_to raise_error
      end

      it 'raises an exception for too many args on a method with positive arity' do
        expect {
          Async::validate_argc(subject, :three, 1, 2, 3, 4)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception for too few args on a method with positive arity' do
        expect {
          Async::validate_argc(subject, :three, 1, 2)
        }.to raise_error(ArgumentError)
      end

      it 'does not raise an exception for correct positive arity' do
        expect {
          Async::validate_argc(subject, :three, 1, 2, 3)
        }.not_to raise_error
      end

      it 'raises an exception for too few args on a method with negative arity' do
        expect {
          Async::validate_argc(subject, :two_plus_two, 1)
        }.to raise_error(ArgumentError)
      end

      it 'does not raise an exception for correct negative arity' do
        expect {
          Async::validate_argc(subject, :two_plus_two, 1, 2)
          Async::validate_argc(subject, :two_plus_two, 1, 2, 3, 4)
          Async::validate_argc(subject, :two_plus_two, 1, 2, 3, 4, 5, 6)

          Async::validate_argc(subject, :many)
          Async::validate_argc(subject, :many, 1, 2)
          Async::validate_argc(subject, :many, 1, 2, 3, 4)
        }.not_to raise_error
      end
    end

    context 'executor' do

      it 'returns the default executor when #executor= has never been called' do
        Concurrent.configuration.should_receive(:global_operation_pool).
          and_return(ImmediateExecutor.new)
        subject = async_class.new
        subject.async.echo(:foo)
      end

      it 'returns the memo after #executor= has been called' do
        executor = ImmediateExecutor.new
        executor.should_receive(:post)
        subject = async_class.new
        subject.executor = executor
        subject.async.echo(:foo)
      end

      it 'raises an exception if #executor= is called after initialization complete' do
        executor = ImmediateExecutor.new
        subject = async_class.new
        subject.async.echo(:foo)
        expect {
          subject.executor = executor
        }.to raise_error(ArgumentError)
      end
    end

    context '#async' do

      it 'raises an error when calling a method that does not exist' do
        expect {
          subject.async.bogus
        }.to raise_error(StandardError)
      end

      it 'raises an error when passing too few arguments' do
        expect {
          subject.async.gather
        }.to raise_error(ArgumentError)
      end

      it 'raises an error when pasing too many arguments (arity >= 0)' do
        expect {
          subject.async.echo(1, 2, 3, 4, 5)
        }.to raise_error(StandardError)
      end

      it 'returns a :pending IVar' do
        val = subject.async.wait(5)
        val.should be_a Concurrent::IVar
        val.should be_pending
      end

      it 'runs the future on the memoized executor' do
        executor = ImmediateExecutor.new
        executor.should_receive(:post).with(any_args)
        subject = async_class.new
        subject.executor = executor
        subject.async.echo(:foo)
      end

      it 'sets the value on success' do
        val = subject.async.echo(:foo)
        val.value.should eq :foo
        val.should be_fulfilled
      end

      it 'sets the reason on failure' do
        ex = ArgumentError.new
        val = subject.async.boom(ex)
        sleep(0.1)
        val.reason.should eq ex
        val.should be_rejected
      end

      it 'sets the reason when giving too many optional arguments' do
        val = subject.async.gather(1, 2, 3, 4, 5)
        sleep(0.1)
        val.reason.should be_a StandardError
        val.should be_rejected
      end

      it 'supports attribute accessors' do
        subject.async.accessor = :foo
        sleep(0.1)
        val = subject.async.accessor
        sleep(0.1)
        val.value.should eq :foo
        subject.accessor.should eq :foo
      end

      it 'supports methods with blocks' do
        val = subject.async.with_block{ :foo }
        sleep(0.1)
        val.value.should eq :foo
      end

      it 'is aliased as #future' do
        val = subject.future.wait(5)
        val.should be_a Concurrent::IVar
      end

      context '#method_missing' do

        it 'defines the method after the first call' do
          expect { subject.async.method(:echo) }.to raise_error(NameError)
          subject.async.echo(:foo)
          sleep(0.1)
          expect { subject.async.method(:echo) }.not_to raise_error
        end

        it 'does not define the method on name/arity exception' do
          expect { subject.async.method(:bogus) }.to raise_error(NameError)
          expect { subject.async.bogus }.to raise_error(NameError)
          expect { subject.async.method(:bogus) }.to raise_error(NameError)
        end
      end
    end

    context '#await' do

      it 'raises an error when calling a method that does not exist' do
        expect {
          subject.await.bogus
        }.to raise_error(StandardError)
      end

      it 'raises an error when passing too few arguments' do
        expect {
          subject.await.gather
        }.to raise_error(ArgumentError)
      end

      it 'raises an error when pasing too many arguments (arity >= 0)' do
        expect {
          subject.await.echo(1, 2, 3, 4, 5)
        }.to raise_error(StandardError)
      end

      it 'returns a :fulfilled IVar' do
        val = subject.await.echo(5)
        val.should be_a Concurrent::IVar
        val.should be_fulfilled
      end

      it 'sets the value on success' do
        val = subject.await.echo(:foo)
        val.value.should eq :foo
        val.should be_fulfilled
      end

      it 'sets the reason on failure' do
        ex = ArgumentError.new
        val = subject.await.boom(ex)
        val.reason.should eq ex
        val.should be_rejected
      end

      it 'sets the reason when giving too many optional arguments' do
        val = subject.await.gather(1, 2, 3, 4, 5)
        val.reason.should be_a StandardError
        val.should be_rejected
      end

      it 'supports attribute accessors' do
        subject.await.accessor = :foo
        val = subject.await.accessor
        val.value.should eq :foo
        subject.accessor.should eq :foo
      end

      it 'supports methods with blocks' do
        val = subject.await.with_block{ :foo }
        val.value.should eq :foo
      end

      it 'is aliased as #delay' do
        val = subject.delay.echo(5)
        val.should be_a Concurrent::IVar
      end

      context '#method_missing' do

        it 'defines the method after the first call' do
          expect { subject.await.method(:echo) }.to raise_error(NameError)
          subject.await.echo(:foo)
          expect { subject.await.method(:echo) }.not_to raise_error
        end

        it 'does not define the method on name/arity exception' do
          expect { subject.await.method(:bogus) }.to raise_error(NameError)
          expect { subject.await.bogus }.to raise_error(NameError)
          expect { subject.await.method(:bogus) }.to raise_error(NameError)
        end
      end
    end

    context 'locking' do

      it 'uses the same mutex for both #async and #await' do
        object = Class.new {
          include Concurrent::Async
          attr_reader :bucket
          def initialize() init_mutex; end
          def gather(seconds, first, *rest)
            sleep(seconds)
            (@bucket ||= []).concat([first])
            @bucket.concat(rest)
          end
        }.new

        object.async.gather(0.5, :a, :b)
        object.await.gather(0, :c, :d)
        object.bucket.should eq [:a, :b, :c, :d]
      end

      context 'raises an InitializationError' do

        let(:async_class) do
          Class.new do
            include Concurrent::Async
            def echo(msg) msg; end
          end
        end

        it 'when #async is called before #init_mutex' do
          expect {
            async_class.new.async.echo(:foo)
          }.to raise_error(Concurrent::InitializationError)
        end

        it 'when #await is called before #init_mutex' do
          expect {
            async_class.new.async.echo(:foo)
          }.to raise_error(Concurrent::InitializationError)
        end

        it 'when #executor= is called before #init_mutex' do
          expect {
            async_class.new.executor = Concurrent::ImmediateExecutor.new
          }.to raise_error(Concurrent::InitializationError)
        end
      end
    end
  end
end

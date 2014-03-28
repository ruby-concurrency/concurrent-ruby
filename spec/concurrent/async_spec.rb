require 'spec_helper'

module Concurrent

  describe Async do

    subject do
      Class.new {
        include Concurrent::Async
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
      }.new
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

      it 'returns a :pending Future' do
        val = subject.async.wait(5)
        val.should be_a Concurrent::Future
        val.should be_pending
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

      it 'is aliased as #future' do
        val = subject.future.wait(5)
        val.should be_a Concurrent::Future
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

        it 'uses the same mutex as #await' do
          subject.await.mutex.should eq subject.async.mutex
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

      it 'is aliased as #defer' do
        val = subject.defer.echo(5)
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

        it 'uses the same mutex as #async' do
          subject.await.mutex.should eq subject.async.mutex
        end
      end
    end
  end
end

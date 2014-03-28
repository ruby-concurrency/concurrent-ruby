require 'spec_helper'

module Concurrent

  describe Async do

    described_class do
      Class.new do
        include Concurrent::Async
        def echo(msg)
          sleep(rand)
          msg
        end
      end
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
        }.to_not raise_error
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
        }.to_not raise_error
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
        }.to_not raise_error
      end
    end

    context '#async' do
      pending
    end

    context '#await' do
      pending
    end
  end
end

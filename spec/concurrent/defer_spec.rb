require 'spec_helper'

module Concurrent

  describe Defer do

    before(:each) do
      Defer.thread_pool = FixedThreadPool.new(1)
    end

    context '#initialize' do

      it 'raises an exception if no block or operation given' do
        lambda {
          Defer.new
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception if both a block and an operation given' do
        lambda {
          operation = proc{ nil }
          Defer.new(op: operation){ nil }
        }.should raise_error(ArgumentError)
      end

      it 'starts the thread if an operation is given' do
        Defer.thread_pool.should_receive(:post).once.with(any_args())
        operation = proc{ nil }
        Defer.new(op: operation)
      end

      it 'does not start the thread if neither a callback or errorback is given' do
        Defer.thread_pool.should_not_receive(:post)
        Defer.new{ nil }
      end
    end

    context '#then' do

      it 'raises an exception if no block given' do
        lambda {
          Defer.new{ nil }.then
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception if called twice' do
        lambda {
          Defer.new{ nil }.then{|result| nil }.then{|result| nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'raises an exception if an operation was provided at construction' do
        lambda {
          operation = proc{ nil }
          Defer.new(op: operation).then{|result| nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'raises an exception if a callback was provided at construction' do
        lambda {
          callback = proc{|result|nil }
          Defer.new(callback: callback){ nil }.then{|result| nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'returns self' do
        deferred = Defer.new{ nil }
        deferred.then{|result| nil }.should eq deferred
      end
    end

    context '#rescue' do

      it 'raises an exception if no block given' do
        lambda {
          Defer.new{ nil }.rescue
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception if called twice' do
        lambda {
          Defer.new{ nil }.rescue{ nil }.rescue{ nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'raises an exception if an operation was provided at construction' do
        lambda {
          operation = proc{ nil }
          Defer.new(op: operation).rescue{|ex| nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'raises an exception if an errorback was provided at construction' do
        lambda {
          errorback = proc{|ex| nil }
          Defer.new(errorback: errorback){ nil }.rescue{|ex| nil }
        }.should raise_error(IllegalMethodCallError)
      end

      it 'returns self' do
        deferred = Defer.new{ nil }
        deferred.rescue{|ex| nil }.should eq deferred
      end

      it 'aliases #catch' do
        lambda {
          Defer.new{ nil }.catch{|ex| nil }
        }.should_not raise_error
      end

      it 'aliases #on_error' do
        lambda {
          Defer.new{ nil }.on_error{|ex| nil }
        }.should_not raise_error
      end
    end

    context '#go' do

      it 'starts the thread if not started' do
        deferred = Defer.new{ nil }
        Defer.thread_pool.should_receive(:post).once.with(any_args())
        deferred.go
      end

      it 'does nothing if called more than once' do
        deferred = Defer.new{ nil }
        deferred.go
        Defer.thread_pool.should_not_receive(:post)
        deferred.go
      end

      it 'does nothing if thread started at construction' do
        operation = proc{ nil }
        callback = proc{|result| nil }
        errorback = proc{|ex| nil }
        deferred = Defer.new(op: operation, callback: callback, errorback: errorback)
        Defer.thread_pool.should_not_receive(:post)
        deferred.go
      end
    end

    context 'fulfillment' do

      it 'runs the operation' do
        @expected = false
        Defer.new{ @expected = true }.go
        sleep(0.1)
        @expected.should be_true
      end

      it 'calls the callback when the operation is successful' do
        @expected = false
        Defer.new{ true }.then{|result| @expected = true }.go
        sleep(0.1)
        @expected.should be_true
      end

      it 'passes the result of the block to the callback' do
        @expected = false
        Defer.new{ 'w00t' }.then{|result| @expected = result }.go
        sleep(0.1)
        @expected.should eq 'w00t'
      end

      it 'does not call the errorback when the operation is successful' do
        @expected = true
        Defer.new{ nil }.rescue{|ex| @expected = false }.go
        sleep(0.1)
        @expected.should be_true
      end

      it 'calls the errorback if the operation throws an exception' do
        @expected = false
        Defer.new{ raise StandardError }.rescue{|ex| @expected = true }.go
        sleep(0.1)
        @expected.should be_true
      end

      it 'passes the exception object to the errorback' do
        @expected = nil
        Defer.new{ raise StandardError }.rescue{|ex| @expected = ex }.go
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'does not call the callback when the operation fails' do
        @expected = true
        Defer.new{ raise StandardError }.then{|result| @expected = false }.go
        sleep(0.1)
        @expected.should be_true
      end
    end
  end
end

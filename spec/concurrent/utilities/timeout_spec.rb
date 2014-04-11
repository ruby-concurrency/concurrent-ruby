require 'spec_helper'

module Concurrent

  describe '#timeout' do

    it 'raises an exception if no block is given' do
      expect {
        Concurrent::timeout(1)
      }.to raise_error
    end

    it 'returns the value of the block on success' do
      result = Concurrent::timeout(1) { 42 }
      result.should eq 42
    end

    it 'raises an exception if the timeout value is reached' do
      expect {
        Concurrent::timeout(1){ sleep }
      }.to raise_error(Concurrent::TimeoutError)
    end

    it 'bubbles thread exceptions' do
      expect {
        Concurrent::timeout(1){ raise NotImplementedError }
      }.to raise_error
    end

    it 'kills the thread on success' do
      result = Concurrent::timeout(1) { 42 }
      Thread.should_receive(:kill).with(any_args())
      Concurrent::timeout(1){ 42 }
    end

    it 'kills the thread on timeout' do
      Thread.should_receive(:kill).with(any_args())
      expect {
        Concurrent::timeout(1){ sleep }
      }.to raise_error
    end

    it 'kills the thread on exception' do
      Thread.should_receive(:kill).with(any_args())
      expect {
        Concurrent::timeout(1){ raise NotImplementedError }
      }.to raise_error
    end
  end
end

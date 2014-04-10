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

  describe '#timer' do

    it 'raises an exception when no block given' do
      expect {
        Concurrent::timer(0.1)
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception if the interval is less than 0 seconds' do
      expect {
        Concurrent::timer(-1){ :foo }
      }.to raise_error(ArgumentError)
    end

    it 'executes the block after the given number of seconds' do
      start = Time.now
      expected = Concurrent::AtomicFixnum.new(0)
      Concurrent::timer(0.5){ expected.increment }
      expected.value.should eq 0
      sleep(0.2)
      expected.value.should eq 0
      sleep(0.5)
      expected.value.should eq 1
    end

    it 'suppresses exceptions thrown by the block' do
      expect {
        Concurrent::timer(0.5){ raise Exception }
      }.to_not raise_error
    end

    it 'runs the task on the global timer pool' do
      Concurrent.configuration.global_timer_pool.should_receive(:post).with(no_args)
      Concurrent::timer(0.1){ :foo }
    end
  end
end

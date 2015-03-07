require 'hitimes'

module Concurrent

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
      latch = CountDownLatch.new(1)
      duration = Hitimes::Interval.measure do
        Concurrent::timer(0.1){ latch.count_down }
        latch.wait(1)
      end
      expect(duration).to be_within(0.05).of(0.1)
    end

    it 'suppresses exceptions thrown by the block' do
      expect {
        Concurrent::timer(0.5){ raise Exception }
      }.to_not raise_error
    end

    it 'passes all arguments to the block' do
      expected = nil
      latch = CountDownLatch.new(1)
      Concurrent::timer(0, 1, 2, 3) do |*args|
        expected = args
        latch.count_down
      end
      latch.wait(0.2)
      expect(expected).to eq [1, 2, 3]
    end

    it 'runs the task on the global timer pool' do
      expect(Concurrent.configuration.global_timer_set).to receive(:post).with(0.1)
      Concurrent::timer(0.1){ :foo }
    end
  end
end

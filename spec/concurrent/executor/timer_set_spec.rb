module Concurrent

  describe TimerSet do

    subject{ TimerSet.new(executor: ImmediateExecutor.new) }

    after(:each){ subject.kill }

    it 'uses the executor given at construction' do
      executor = double(:executor)
      expect(executor).to receive(:post).with(no_args)
      subject = TimerSet.new(executor: executor)
      subject.post(0){ nil }
      sleep(0.1)
    end

    it 'uses the global io executor be default' do
      expect(Concurrent.global_io_executor).to receive(:post).with(no_args)
      subject = TimerSet.new
      subject.post(0){ nil }
      sleep(0.1)
    end

    it 'executes a given task when given a Time' do
      warn 'deprecated syntax'
      latch = CountDownLatch.new(1)
      subject.post(Time.now + 0.1){ latch.count_down }
      expect(latch.wait(0.2)).to be_truthy
    end

    it 'executes a given task when given an interval in seconds' do
      latch = CountDownLatch.new(1)
      subject.post(0.1){ latch.count_down }
      expect(latch.wait(0.2)).to be_truthy
    end

    it 'returns true when posting a task' do
      expect(subject.post(0.1) { nil }).to be true
    end

    it 'executes a given task when given an interval in seconds, even if longer tasks have been scheduled' do
      latch = CountDownLatch.new(1)
      subject.post(0.5){ nil }
      sleep 0.1
      subject.post(0.1){ latch.count_down }
      expect(latch.wait(0.2)).to be_truthy
    end

    it 'passes all arguments to the task on execution' do
      expected = nil
      latch = CountDownLatch.new(1)
      subject.post(0.1, 1, 2, 3) do |*args|
        expected = args
        latch.count_down
      end
      expect(latch.wait(0.2)).to be_truthy
      expect(expected).to eq [1, 2, 3]
    end

    it 'immediately posts a task when the delay is zero' do
      expect(Thread).not_to receive(:new).with(any_args)
      subject.post(0){ true }
    end

    it 'does not execute tasks early' do
      latch = Concurrent::CountDownLatch.new(1)
      start = Time.now.to_f
      subject.post(0.2){ latch.count_down }
      expect(latch.wait(1)).to be true
      expect(Time.now.to_f - start).to be_within(0.1).of(0.2)
    end

    it 'raises an exception when given a task with a past Time value' do
      warn 'deprecated syntax'
      expect {
        subject.post(Time.now - 10){ nil }
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception when given a task with a delay less than zero' do
      expect {
        subject.post(-10){ nil }
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception when no block given' do
      expect {
        subject.post(10)
      }.to raise_error(ArgumentError)
    end

    it 'executes all tasks scheduled for the same time' do
      latch = CountDownLatch.new(5)
      5.times{ subject.post(0.1){ latch.count_down } }
      expect(latch.wait(0.2)).to be_truthy
    end

    it 'executes tasks with different times in schedule order' do
      latch = CountDownLatch.new(3)
      expected = []
      3.times{|i| subject.post(i/10){ expected << i; latch.count_down } }
      latch.wait(1)
      expect(expected).to eq [0, 1, 2]
    end

    it 'executes tasks with different times in schedule time' do
      tests = 3
      interval = 0.1
      latch = CountDownLatch.new(tests)
      expected = Queue.new
      start = Time.now

      (1..tests).each do |i|
        subject.post(interval * i) { expected << Time.now - start; latch.count_down }
      end

      expect(latch.wait((tests * interval) + 1)).to be true

      (1..tests).each do |i|
        delta = expected.pop
        expect(delta).to be_within(0.1).of((i * interval) + 0.05)
      end
    end

    it 'cancels all pending tasks on #shutdown' do
      expected = AtomicFixnum.new(0)
      10.times{ subject.post(0.2){ expected.increment } }
      sleep(0.1)
      subject.shutdown
      sleep(0.2)
      expect(expected.value).to eq 0
    end

    it 'cancels all pending tasks on #kill' do
      expected = AtomicFixnum.new(0)
      10.times{ subject.post(0.2){ expected.increment } }
      sleep(0.1)
      subject.kill
      sleep(0.2)
      expect(expected.value).to eq 0
    end

    it 'stops the monitor thread on #shutdown' do
      timer_executor = subject.instance_variable_get(:@timer_executor)
      subject.shutdown
      sleep(0.1)
      expect(timer_executor).not_to be_running
    end

    it 'kills the monitor thread on #kill' do
      timer_executor = subject.instance_variable_get(:@timer_executor)
      subject.kill
      sleep(0.1)
      expect(timer_executor).not_to be_running
    end

    it 'rejects tasks once shutdown' do
      expected = AtomicFixnum.new(0)
      subject.shutdown
      sleep(0.1)
      expect(subject.post(0){ expected.increment }).to be_falsey
      sleep(0.1)
      expect(expected.value).to eq 0
    end

    it 'rejects tasks once killed' do
      expected = AtomicFixnum.new(0)
      subject.kill
      sleep(0.1)
      expect(subject.post(0){ expected.increment }).to be_falsey
      sleep(0.1)
      expect(expected.value).to eq 0
    end

    it 'is running? when first created' do
      expect(subject).to be_running
      expect(subject).not_to be_shutdown
    end

    it 'is running? after tasks have been post' do
      subject.post(0.1){ nil }
      expect(subject).to be_running
      expect(subject).not_to be_shutdown
    end

    it 'is shutdown? after shutdown completes' do
      subject.shutdown
      sleep(0.1)
      expect(subject).not_to be_running
      expect(subject).to be_shutdown
    end

    it 'is shutdown? after being killed' do
      subject.kill
      sleep(0.1)
      expect(subject).not_to be_running
      expect(subject).to be_shutdown
    end

    specify '#wait_for_termination returns true if shutdown completes before timeout' do
      subject.post(0.1){ nil }
      sleep(0.1)
      subject.shutdown
      expect(subject.wait_for_termination(0.1)).to be_truthy
    end

    specify '#wait_for_termination returns false on timeout' do
      subject.post(0.1){ nil }
      sleep(0.1)
      # do not call shutdown -- force timeout
      expect(subject.wait_for_termination(0.1)).to be_falsey
    end
  end
end

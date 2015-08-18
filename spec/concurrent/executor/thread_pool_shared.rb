require_relative 'executor_service_shared'

shared_examples :thread_pool do

  after(:each) do
    subject.kill
    subject.wait_for_termination(0.1)
  end

  it_should_behave_like :executor_service

  if described_class.instance_methods.include? :prioritized
    specify { expect(subject).to_not be_prioritized }
  end

  context '#auto_terminate?' do

    it 'returns true by default' do
      expect(subject.auto_terminate?).to be true
    end

    it 'returns true when :enable_at_exit_handler is true' do
      if described_class.to_s =~ /FixedThreadPool$/
        subject = described_class.new(1, auto_terminate: true)
      else
        subject = described_class.new(auto_terminate: true)
      end
      expect(subject.auto_terminate?).to be true
    end

    it 'returns false when :enable_at_exit_handler is false' do
      if described_class.to_s =~ /FixedThreadPool$/
        subject = described_class.new(1, auto_terminate: false)
      else
        subject = described_class.new(auto_terminate: false)
      end
      expect(subject.auto_terminate?).to be false
    end
  end

  context '#length' do

    it 'returns zero on creation' do
      expect(subject.length).to eq 0
    end

    it 'returns zero once shut down' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.length).to eq 0
    end
  end

  context '#scheduled_task_count' do

    it 'returns zero on creation' do
      expect(subject.scheduled_task_count).to eq 0
    end

    it 'returns the approximate number of tasks that have been post thus far' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.scheduled_task_count).to be > 0
    end

    it 'returns the approximate number of tasks that were post' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.scheduled_task_count).to be > 0
    end
  end

  context '#completed_task_count' do

    it 'returns zero on creation' do
      expect(subject.completed_task_count).to eq 0
    end

    it 'returns the approximate number of tasks that have been completed thus far' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.completed_task_count).to be > 0
    end

    it 'returns the approximate number of tasks that were completed' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.completed_task_count).to be > 0
    end
  end

  context '#shutdown' do

    it 'allows threads to exit normally' do
      10.times{ subject << proc{ nil } }
      expect(subject.length).to be > 0
      sleep(0.1)
      subject.shutdown
      sleep(1)
      expect(subject.length).to eq(0)
    end
  end
end

shared_examples :prioritized_thread_pool do

  after(:each) do
    subject.kill
    subject.wait_for_termination(0.1)
  end

  specify { expect(subject).to be_prioritized }

  it 'executes tasks in priority order' do
    count = 10
    start_latch = Concurrent::CountDownLatch.new
    continue_latch = Concurrent::CountDownLatch.new
    end_latch = Concurrent::CountDownLatch.new(count)
    actual = []

    subject.post{ start_latch.count_down; continue_latch.wait(1) }
    start_latch.wait(1)

    [*1..count].shuffle.each do |i|
      subject.prioritize(i, i) do |x|
        actual << x
        end_latch.count_down
      end
    end

    continue_latch.count_down
    end_latch.wait(1)

    expect(actual).to eq [*1..count].reverse
  end

  it 'executes unprioritized tasks last' do
    count = 5
    filler = 42
    start_latch = Concurrent::CountDownLatch.new
    continue_latch = Concurrent::CountDownLatch.new
    end_latch = Concurrent::CountDownLatch.new(count * 2)
    actual = []

    subject.post{ start_latch.count_down; continue_latch.wait(1) }
    start_latch.wait(1)

    [*1..count].shuffle.each do |i|
      subject.prioritize(i, i) do |x|
        actual << x
        end_latch.count_down
      end
    end

    [*count+1..count*2].shuffle.each do |i|
      subject.post do
        actual << filler
        end_latch.count_down
      end
    end

    continue_latch.count_down
    end_latch.wait(1)

    expect(actual).to eq [*1..count].reverse + Array.new(count, filler)
  end
end

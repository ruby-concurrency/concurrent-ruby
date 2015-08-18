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

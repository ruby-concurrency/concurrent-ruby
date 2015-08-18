shared_examples 'exchanger method with indefinite timeout' do

  before(:each) do
    subject # ensure proper initialization
  end

  it 'blocks indefinitely' do
    latch_1 = Concurrent::CountDownLatch.new
    latch_2 = Concurrent::CountDownLatch.new

    t = Thread.new do
      latch_1.count_down
      subject.send(method, 1)
      latch_2.count_down
    end

    latch_1.wait(1)
    latch_2.wait(0.1)
    expect(latch_2.count).to eq 1
    t.kill
  end

  it 'receives the other value' do
    first_value = nil
    second_value = nil
    latch = Concurrent::CountDownLatch.new(2)

    threads = [
      Thread.new { first_value = subject.send(method, 2); latch.count_down },
      Thread.new { second_value = subject.send(method, 4); latch.count_down }
    ]

    latch.wait(1)

    expect(get_value(first_value)).to eq 4
    expect(get_value(second_value)).to eq 2

    threads.each {|t| t.kill }
  end

  it 'can be reused' do
    first_value = nil
    second_value = nil
    latch_1 = Concurrent::CountDownLatch.new(2)
    latch_2 = Concurrent::CountDownLatch.new(2)

    threads = [
      Thread.new { first_value = subject.send(method, 1); latch_1.count_down },
      Thread.new { second_value = subject.send(method, 0); latch_1.count_down }
    ]

    latch_1.wait(1)
    threads.each {|t| t.kill }

    threads = [
      Thread.new { first_value = subject.send(method, 10); latch_2.count_down },
      Thread.new { second_value = subject.send(method, 12); latch_2.count_down }
    ]

    latch_2.wait(1)
    expect(get_value(first_value)).to eq 12
    expect(get_value(second_value)).to eq 10
    threads.each {|t| t.kill }
  end
end

shared_examples 'exchanger method with finite timeout' do

  it 'blocks until timeout' do
    duration = Concurrent::TestHelpers.monotonic_interval do
      begin
        subject.send(method, 2, 0.1)
      rescue Concurrent::TimeoutError
        # do nothing
      end
    end
    expect(duration).to be_within(0.05).of(0.1)
  end

  it 'receives the other value' do
    first_value = nil
    second_value = nil
    latch = Concurrent::CountDownLatch.new(2)

    threads = [
      Thread.new { first_value = subject.send(method, 2, 1); latch.count_down },
      Thread.new { second_value = subject.send(method, 4, 1); latch.count_down }
    ]

    latch.wait(1)

    expect(get_value(first_value)).to eq 4
    expect(get_value(second_value)).to eq 2

    threads.each {|t| t.kill }
  end

  it 'can be reused' do
    first_value = nil
    second_value = nil
    latch_1 = Concurrent::CountDownLatch.new(2)
    latch_2 = Concurrent::CountDownLatch.new(2)

    threads = [
      Thread.new { first_value = subject.send(method, 1, 1); latch_1.count_down },
      Thread.new { second_value = subject.send(method, 0, 1); latch_1.count_down }
    ]

    latch_1.wait(1)
    threads.each {|t| t.kill }

    threads = [
      Thread.new { first_value = subject.send(method, 10, 1); latch_2.count_down },
      Thread.new { second_value = subject.send(method, 12, 1); latch_2.count_down }
    ]

    latch_2.wait(1)
    expect(get_value(first_value)).to eq 12
    expect(get_value(second_value)).to eq 10
    threads.each {|t| t.kill }
  end
end

shared_examples 'exchanger method cross-thread interactions' do

  it 'when first, waits for a second' do
    first_value = nil
    second_value = nil
    latch = Concurrent::CountDownLatch.new(1)

    t1 = Thread.new do
      first_value = subject.send(method, :foo, 1)
      latch.count_down
    end
    t1.join(0.1)

    second_value = subject.send(method, :bar, 0)
    latch.wait(1)

    expect(get_value(first_value)).to eq :bar
    expect(get_value(second_value)).to eq :foo

    t1.kill
  end

  it 'allows multiple firsts to cancel if necessary' do
    first_value = nil
    second_value = nil
    cancels = 3
    cancel_latch = Concurrent::CountDownLatch.new(cancels)
    success_latch = Concurrent::CountDownLatch.new(1)

    threads = cancels.times.collect do
      Thread.new do
        begin
          first_value = subject.send(method, :foo, 0.1)
        rescue Concurrent::TimeoutError
          # suppress
        ensure
          cancel_latch.count_down
        end
      end
    end

    threads.each {|t| t.join(1) }
    cancel_latch.wait(1)

    t1 = Thread.new do
      first_value = subject.send(method, :bar, 1)
      success_latch.count_down
    end
    t1.join(0.1)

    second_value = subject.send(method, :baz, 0)
    success_latch.wait(1)

    expect(get_value(first_value)).to eq :baz
    expect(get_value(second_value)).to eq :bar

    t1.kill
    threads.each {|t| t.kill }
  end
end

shared_examples :exchanger do

  context '#exchange' do
    let!(:method) { :exchange }
    def get_value(result) result end
    it_behaves_like 'exchanger method with indefinite timeout'
    it_behaves_like 'exchanger method with finite timeout'
    it_behaves_like 'exchanger method cross-thread interactions'
  end

  context '#exchange!' do
    let!(:method) { :exchange! }
    def get_value(result) result end
    it_behaves_like 'exchanger method with indefinite timeout'
    it_behaves_like 'exchanger method with finite timeout'
    it_behaves_like 'exchanger method cross-thread interactions'
  end

  context '#try_exchange' do
    let!(:method) { :try_exchange }
    def get_value(result) result.value end
    it_behaves_like 'exchanger method with indefinite timeout'
    it_behaves_like 'exchanger method with finite timeout'
    it_behaves_like 'exchanger method cross-thread interactions'
  end
end

module Concurrent

  describe RubyExchanger do

    it_behaves_like :exchanger

    if Concurrent.on_cruby?

      specify 'stress test', notravis: true do
        thread_count = 100
        exchange_count = 100
        latch = Concurrent::CountDownLatch.new(thread_count)

        good = Concurrent::AtomicFixnum.new(0)
        bad = Concurrent::AtomicFixnum.new(0)
        ugly = Concurrent::AtomicFixnum.new(0)

        threads = thread_count.times.collect do |i|
          Thread.new do
            exchange_count.times do |j|
              begin
                result = subject.exchange!(i, 1)
                result == i ? ugly.up : good.up
              rescue Concurrent::TimeoutError
                bad.up
              end
            end
            latch.count_down
          end
        end

        latch.wait

        puts "Good: #{good.value}, Bad (timeout): #{bad.value}, Ugly: #{ugly.value}"
        expect(good.value + bad.value + ugly.value).to eq thread_count * exchange_count
        expect(ugly.value).to eq 0

        threads.each {|t| t.kill }
      end
    end
  end

  if defined? JavaExchanger

    describe JavaExchanger do
      it_behaves_like :exchanger
    end
  end

  describe Exchanger do

    context 'class hierarchy'  do

      if Concurrent.on_jruby?
        it 'inherits from JavaExchanger' do
          expect(Exchanger.ancestors).to include(JavaExchanger)
        end
      else
        it 'inherits from RubyExchanger' do
          expect(Exchanger.ancestors).to include(RubyExchanger)
        end
      end
    end
  end
end

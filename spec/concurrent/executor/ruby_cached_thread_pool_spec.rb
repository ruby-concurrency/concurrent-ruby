require_relative 'cached_thread_pool_shared'

module Concurrent

  describe RubyCachedThreadPool, :type => :mrirbx do

    subject do
      described_class.new(
          fallback_policy: :discard,
          gc_interval:     0
      )
    end

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :cached_thread_pool

    context 'garbage collection' do

      subject { described_class.new(idletime: 0.1, max_threads: 2, gc_interval: 0) }

      it 'removes from pool any thread that has been idle too long' do
        latch = Concurrent::CountDownLatch.new(4)
        4.times { subject.post { sleep 0.1; latch.count_down } }
        expect(latch.wait(1)).to be true
        sleep 0.2
        subject.post {}
        sleep 0.2
        expect(subject.length).to be < 4
      end

      it 'removes from pool any dead thread' do
        latch = Concurrent::CountDownLatch.new(3)
        3.times { subject << proc { sleep(0.1); latch.count_down; raise Exception } }
        expect(latch.wait(1)).to be true

        max_threads = subject.length
        sleep(2)

        latch = Concurrent::CountDownLatch.new(1)
        subject << proc { latch.count_down }
        expect(latch.wait(1)).to be true

        expect(subject.length).to be < max_threads
      end
    end

    context 'worker creation and caching' do

      subject { described_class.new(idletime: 1, max_threads: 5) }

      it 'creates new workers when there are none available' do
        expect(subject.length).to eq 0
        5.times { sleep(0.1); subject << proc { sleep(1) } }
        sleep(1)
        expect(subject.length).to eq 5
      end

      it 'uses existing idle threads' do
        5.times { subject << proc { sleep(0.1) } }
        sleep(1)
        expect(subject.length).to be >= 5
        3.times { subject << proc { sleep(1) } }
        sleep(0.1)
        expect(subject.length).to be >= 5
      end
    end
  end


  context 'stress' do
    configurations = [
        { min_threads:     2,
          max_threads:     ThreadPoolExecutor::DEFAULT_MAX_POOL_SIZE,
          stop_on_exit:    false,
          idletime:        0.1, # 1 minute
          max_queue:       0, # unlimited
          fallback_policy: :caller_runs, # shouldn't matter -- 0 max queue
          gc_interval:     0.1 },
        { min_threads:     2,
          max_threads:     4,
          stop_on_exit:    false,
          idletime:        0.1, # 1 minute
          max_queue:       0, # unlimited
          fallback_policy: :caller_runs, # shouldn't matter -- 0 max queue
          gc_interval:     0.1 }
    ]


    configurations.each do |config|
      specify do
        pool = RubyThreadPoolExecutor.new(config)

        100.times do
          count = Concurrent::CountDownLatch.new(100)
          100.times do
            pool.post { count.count_down }
          end
          count.wait
          expect(pool.length).to be <= [110, config[:max_threads]].min
          if pool.length > [110, config[:max_threads]].min
            puts "ERRORSIZE #{pool.length} max #{config[:max_threads]}"
          end
        end
      end

    end


  end
end

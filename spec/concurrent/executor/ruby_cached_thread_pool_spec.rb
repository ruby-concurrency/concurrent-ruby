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

      it 'deals with dead threads' do
        expect(subject).to receive(:ns_worker_died).exactly(5).times.and_call_original

        dead_threads_queue = Queue.new
        5.times { subject.post { sleep 0.1; dead_threads_queue.push Thread.current; raise Exception } }
        sleep(0.2)
        latch = Concurrent::CountDownLatch.new(5)
        5.times { subject.post { sleep 0.1; latch.count_down } }
        expect(latch.wait(1)).to be true

        dead_threads = []
        dead_threads << dead_threads_queue.pop until dead_threads_queue.empty?
        expect(dead_threads.all? { |t| !t.alive? }).to be true
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
          auto_terminate:  false,
          idletime:        0.1, # 1 minute
          max_queue:       0, # unlimited
          fallback_policy: :caller_runs, # shouldn't matter -- 0 max queue
          gc_interval:     0.1 },
        { min_threads:     2,
          max_threads:     4,
          auto_terminate:  false,
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
          expect(pool.length).to be <= [200, config[:max_threads]].min
          if pool.length > [110, config[:max_threads]].min
            puts "ERRORSIZE #{pool.length} max #{config[:max_threads]}"
          end
        end
      end

    end


  end
end

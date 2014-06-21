require 'spec_helper'
require_relative 'thread_pool_shared'
require 'thread'

share_examples_for :fixed_thread_pool do

  let!(:num_threads){ 5 }
  subject { described_class.new(num_threads) }

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool

  context '#initialize default values' do

    subject { described_class.new(5) }

    it 'defaults :min_length correctly' do
      subject.min_length.should eq 5
    end

    it 'defaults :max_length correctly' do
      subject.max_length.should eq 5
    end

    it 'defaults :overflow_policy to :abort' do
      subject.overflow_policy.should eq :abort
    end


    it 'defaults :idletime correctly' do
      subject.idletime.should eq subject.class.const_get(:DEFAULT_THREAD_IDLETIMEOUT)
    end

    it 'defaults default :max_queue to zero' do
      subject.max_queue.should eq 0
    end

  end

  context '#initialize explicit values' do

    it 'raises an exception when the pool length is less than one' do
      lambda {
        described_class.new(0)
      }.should raise_error(ArgumentError)
    end


    it 'sets explicit :max_queue correctly' do
      subject = described_class.new(5, :max_queue => 10)
      subject.max_queue.should eq 10
    end

    it 'correctly sets valid :overflow_policy' do
      subject = described_class.new(5, :overflow_policy => :caller_runs)
      subject.overflow_policy.should eq :caller_runs
    end

    it "correctly sets valid :idletime" do
      subject = described_class.new(5, :idletime => 10)
      subject.idletime.should eq 10
    end

    it 'raises an exception if given an invalid :overflow_policy' do
      expect {
        described_class.new(5, overflow_policy: :bogus)
      }.to raise_error(ArgumentError)
    end


  end

  context '#min_length' do

    it 'returns :num_threads on creation' do
      subject.min_length.should eq num_threads
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.min_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.min_length.should eq num_threads
    end
  end

  context '#max_length' do

    it 'returns :num_threads on creation' do
      subject.max_length.should eq num_threads
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.max_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.max_length.should eq num_threads
    end
  end

  context '#length' do

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.length.should eq num_threads
    end
  end

  context '#largest_length' do

    it 'returns zero on creation' do
      subject.largest_length.should eq 0
    end

    it 'returns :num_threads while running' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.largest_length.should eq num_threads
    end

    it 'returns :num_threads once shutdown' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.largest_length.should eq num_threads
    end
  end

  context '#status' do

    it 'returns an array' do
      subject.stub(:warn)
      subject.status.should be_kind_of(Array)
    end
  end


  context '#kill' do

    it 'attempts to kill all in-progress tasks' do
      thread_count = [subject.length, 5].max
      @expected = false
      thread_count.times{ subject.post{ sleep(1) } }
      subject.post{ @expected = true }
      sleep(0.1)
      subject.kill
      sleep(0.1)
      @expected.should be_false
    end
  end

  context 'worker creation and caching' do

    it 'never creates more than :num_threads threads' do
      pool = described_class.new(5)
      100.times{ pool << proc{ sleep(1) } }
      sleep(0.1)
      pool.current_length.should eq 5
      pool.kill
    end
  end

  context 'overflow policy' do

    before do
      @queue = Queue.new
    end

    # On abort, it should raise an error
    it "raises an error when overflow on abort" do
      latch = Concurrent::CountDownLatch.new(5)
      mutex = Mutex.new

      subject = described_class.new(2, :max_queue => 2, :overflow_policy => :abort)
      expect {
        5.times do |i|
          subject.post do
            sleep 0.1
            mutex.synchronize{ @queue << i }
            latch.count_down
          end
        end
        subject.shutdown
        latch.wait(1)
      }.to raise_error
    end

    # On discard, we'd expect no error, but also not all five results
    it 'discards when overflow is :discard' do
      latch = Concurrent::CountDownLatch.new(5)
      mutex = Mutex.new

      subject = described_class.new(2, :max_queue => 2, :overflow_policy => :discard)
      5.times do |i|
        subject.post do
          sleep 0.1
          mutex.synchronize{ @queue << i }
          latch.count_down
        end
      end
      subject.shutdown
      latch.wait(1)

      @queue.length.should be < 5
    end

    # To check for caller_runs, we'll check how many unique threads
    # actually ran the block

    it 'uses the calling thread for overflow under caller_runs' do
      latch = Concurrent::CountDownLatch.new(5)
      mutex = Mutex.new

      subject = described_class.new(2, :max_queue => 2, :overflow_policy => :caller_runs)

      5.times do |i|
        subject.post do
          sleep 0.1
          mutex.synchronize{ @queue << Thread.current }
          latch.count_down
        end
      end
      subject.shutdown
      latch.wait(1)

      # Turn the queue into an array
      a = []
      a << @queue.shift until @queue.empty?

      a.size.should eq 5 # one for each run of the block
      a.uniq.size.should eq 3 # one for each of teh two threads, plus the caller
    end
  end
end

require_relative 'spec_helper'

module Concurrent

  describe CachedThreadPool do

    TEST_COUNT = (ENV['TESTS'] || 1000).to_i
    THREAD_COUNT = (ENV['THREADS'] || CachedThreadPool::MAX_POOL_SIZE).to_i

    it "runs #{TEST_COUNT} tests against #{THREAD_COUNT} threads" do

      pool = CachedThreadPool.new(max_threads: THREAD_COUNT)
      @tally = Stressor::Tally.new
      @done = Concurrent::Event.new
      @tests = 0

      TEST_COUNT.times do
        pool.post do
          @tally << Stressor::test(Stressor::random_dataset)
          total = @tally.total
          print '.' if total % 10 == 0
          @done.set if total == TEST_COUNT
        end
      end

      @done.wait
      puts
      @tally.good.should == TEST_COUNT
      @tally.bad.should == 0
      @tally.ugly.should == 0
    end
  end
end

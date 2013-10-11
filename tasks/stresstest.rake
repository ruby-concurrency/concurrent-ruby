require 'concurrent'
require_relative 'stresstest/support/word_sec.rb'

namespace :stresstest do

  desc 'Stress test the gem'
  task :all do

    tests = {
      a: {
        file: 'TestdataA.txt',
        total: 13,
        highest_count: 4
      },
      b: {
        file: 'TestdataB.txt',
        total: 80,
        highest_count: 10
      },
      c: {
        file: 'TestdataC.txt',
        total: 180,
        highest_count: 17
      },
      d: {
        file: 'the_art_of_war.txt',
        total: 2563,
        highest_count: 294
      },
      e: {
        file: 'the_republic.txt',
        total: 11497,
        highest_count: 1217
      },
      f: {
        file: 'war_and_peace.txt',
        total: 20532,
        highest_count: 2302
      }
    }

    Tally = Class.new do
      attr_reader :good, :bad, :ugly
      def initialize
        @good, @bad, @ugly = 0, 0, 0
        @mutex = Mutex.new
      end

      def add_good
        @mutex.synchronize { @good += 1 }
      end

      def add_bad
        @mutex.synchronize { @bad += 1 }
      end

      def add_ugly
        @mutex.synchronize { @ugly += 1 }
      end
    end

    test_count = 1000
    threads = 250

    test = tests[:c]

    file_path = File.join(File.dirname(__FILE__), 'stresstest/support', test[:file])

    if jruby?
      pool = Concurrent::CachedThreadPool.new(max: threads)
    else
      pool = Concurrent::FixedThreadPool.new(threads)
    end

    # teardown
    Thread.list.each do |thread|
      thread.kill unless thread == Thread.current
    end

    @tests = 0
    @tally = Tally.new
    @done = Concurrent::Event.new

    counter = proc do
      begin
        infile = File.open(file_path)
        words, total_word_count = make_word_list(infile)
        infile.close
        tally = tally_from_words_array(words, true)
        if tally[:total] == test[:total] && tally[:highest_count] == test[:highest_count]
          @tally.add_good
        else
          @tally.add_bad
        end
      rescue => ex
        @tally.add_ugly
      ensure
        @tests += 1
        @done.set if @tests == test_count
      end
    end

    puts "Running #{test_count} tests with #{threads} threads..."
    test_count.times do
      pool.post(&counter)
    end

    puts "All messages sent. Waiting..."
    @done.wait

    puts "Good: #{@tally.good}, Bad: #{@tally.bad}, Ugly: #{@tally.ugly}"

  end
end

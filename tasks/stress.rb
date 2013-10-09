require 'concurrent'
require_relative 'stress/word_sec.rb'

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

test_count = 1000
threads = 250

test = tests[:c]

file_path = File.join(File.dirname(__FILE__), 'stress', test[:file])

@tests = 0
if Functional::PLATFORM.jruby?
  pool = Concurrent::CachedThreadPool.new(max: threads)
else
  pool = Concurrent::FixedThreadPool.new(threads)
end

# teardown
Thread.list.each do |thread|
  thread.kill unless thread == Thread.current
end

counter = proc do
  begin
    infile = File.open(file_path)
    words, total_word_count = make_word_list(infile)
    infile.close
    stats = stats_from_words_array(words, true)
    if stats[:total] == test[:total] && stats[:highest_count] == test[:highest_count]
      print '.'
    else
      print '*'
    end
  rescue => ex
    print '!'
  ensure
    @tests += 1
    print "\n\n#{@tests} done!\n\n" if @tests == test_count
  end
end

test_count.times do
  pool.post(&counter)
end

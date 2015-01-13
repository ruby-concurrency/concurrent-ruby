require 'concurrent/atomics'
require 'concurrent/configuration'
require 'concurrent/executors'

module Concurrent

  module Parallel
    extend self

    def map(list, opts = {})
      raise ArgumentError.new('no block given') unless block_given?

      executor = OptionsParser::get_executor_from(opts) || Concurrent.configuration.global_task_pool
      latch = Concurrent::CountDownLatch.new(list.size)
      size = list.size

      results = Array.new(size)

      # post a job for every thread
      index = Concurrent::AtomicFixnum.new(-1)
      list.each do |item|
        i = index.increment
        executor.post { results[i] = yield(item); latch.count_down }
      end

      # return the results
      latch.wait
      results
    end
  end
end

# $ bundle exec ruby lib/concurrent/parallel.rb
#        user     system      total        real
# 
# Concurrent::Parallel.map (global task pool)
#   0.010000   0.000000   0.010000 (  0.105637)
# 
# Concurrent::Parallel.map (pre-allocated pool)
#   0.000000   0.010000   0.010000 (  0.101435)
# 
# Concurrent::Parallel--Enumerable (global task pool)
#   0.010000   0.000000   0.010000 (  0.090622)
# 
# Concurrent::Parallel.map--Enumerable (pre-allocated pool)
#   0.000000   0.000000   0.000000 (  0.104036)
# 
# Concurrent::Future
#   0.010000   0.010000   0.020000 (  0.257162)
# 
# Pmap gem
#   0.010000   0.000000   0.010000 (  0.110250)

if $0 == __FILE__

  require 'concurrent/future'
  require 'concurrent/parallel/core_ext' # monkep-patch Enumerable
  require 'pmap'

  require 'open-uri'
  require 'benchmark'
  require 'pp'

  def get_year_end_closing(symbol, year)
    uri = "http://ichart.finance.yahoo.com/table.csv?s=#{symbol}&a=11&b=01&c=#{year}&d=11&e=31&f=#{year}&g=m"
    data = open(uri) {|f| f.collect{|line| line.strip } }
    price = data[1].split(',')[4]
    price.to_f
    [symbol, price.to_f]
  end

  symbols = [:ibm, :goog, :aapl, :msft, :hp, :orcl]
  year = 2014

  Benchmark.bm do |stats|

    puts "\nConcurrent::Parallel.map (global task pool)"
    stats.report do
      prices = Concurrent::Parallel.map(symbols) do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Parallel.map (pre-allocated pool)"
    stats.report do
      executor = Concurrent::FixedThreadPool.new(symbols.size)
      prices = Concurrent::Parallel.map(symbols, executor: executor) do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Parallel--Enumerable (global task pool)"
    stats.report do
      prices = symbols.parallel_map do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Parallel.map--Enumerable (pre-allocated pool)"
    stats.report do
      executor = Concurrent::FixedThreadPool.new(symbols.size)
      prices = Concurrent::Parallel.map(symbols, executor: executor) do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Future"
    stats.report do
      futures = symbols.collect do |symbol|
        Concurrent::Future.execute{ get_year_end_closing(symbol, year) }
      end
      prices = futures.collect {|future| future.value }
      #p prices
    end

    puts "\nPmap gem"
    stats.report do
      prices = symbols.pmap do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end
  end
end

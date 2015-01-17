require 'concurrent/atomics'
require 'concurrent/configuration'
require 'concurrent/executors'

module Concurrent

  class Parallel < SimpleDelegator
    module EnumerableInterface
      module_function

      def use(runner, methods)
        enumerable_methods = Enumerable.instance_methods.map(&:to_s)
        enumerable_methods << 'each'
        methods.each do |method|
          next unless enumerable_methods.include?(method)
          class_eval <<-RUBY
          def #{method}(*args, &block)
            #{runner}(:#{method}, *args, &block)
          end
          RUBY
        end
      end

      use :run_in_threads, %w(
        all? any? count detect find find_index max_by min_by minmax_by none?
        one? partition
      )

      use :run_in_threads_return_original, %w(
        cycle each each_cons each_entry each_slice each_with_index enum_cons
        enum_slice enum_with_index reverse_each zip
      )

      use :run_in_threads_return_parallel, %w(
        collect collect_concat drop_while find_all flat_map grep group_by map
        reject select sort sort_by take_while zip
      )
    end

    protected :__getobj__, :__setobj__

    include EnumerableInterface

    def initialize(list, opts = {})
      super list
      @opts = opts
      @executor = OptionsParser::get_executor_from(opts) || Concurrent.configuration.global_task_pool
    end

    def parallel
      self
    end

    def serial
      __getobj__
    end

    protected

    def run_in_threads(method, *args, &block)
      if block
        latch = Concurrent::CountDownLatch.new(size)

        results = Array.new(size)

        # post a job for every thread
        index = Concurrent::AtomicFixnum.new(-1)
        __getobj__.each do |item|
          i = index.increment
          @executor.post { results[i] = yield(item); latch.count_down }
        end

        # return the results
        latch.wait
        results.send(method, *args) { |value| value }
      else
        send method, *args
      end
    end

    def run_in_threads_return_original(method, *args, &block)
      run_in_threads(method, *args, &block)

      self
    end

    def run_in_threads_return_parallel(method, *args, &block)
      Parallel.new run_in_threads(method, *args, &block), @opts
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
      prices = Concurrent::Parallel.new(symbols).map do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Parallel.map (pre-allocated pool)"
    stats.report do
      executor = Concurrent::FixedThreadPool.new(symbols.size)
      prices = Concurrent::Parallel.new(symbols, executor: executor).map do |symbol|
        get_year_end_closing(symbol, year)
      end
      #p prices
    end

    puts "\nConcurrent::Parallel--Enumerable (global task pool)"
    stats.report do
      prices = symbols.parallel.map do |symbol|
        get_year_end_closing(symbol, year)
      end

      #p prices
    end

    puts "\nConcurrent::Parallel.map--Enumerable (pre-allocated pool)"
    stats.report do
      executor = Concurrent::FixedThreadPool.new(symbols.size)
      prices = Concurrent::Parallel.new(symbols, executor: executor).map do |symbol|
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

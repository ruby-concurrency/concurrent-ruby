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

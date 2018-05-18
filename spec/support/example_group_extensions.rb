require 'rbconfig'
require 'concurrent/synchronization'

module Concurrent
  module TestHelpers
    extend self

    def delta(v1, v2)
      if block_given?
        v1 = yield(v1)
        v2 = yield(v2)
      end
      return (v1 - v2).abs
    end

    include Utility::EngineDetector

    def use_c_extensions?
      Concurrent.allow_c_extensions?
    end

    def monotonic_interval
      raise ArgumentError.new('no block given') unless block_given?
      start_time = GLOBAL_MONOTONIC_CLOCK.get_time
      yield
      GLOBAL_MONOTONIC_CLOCK.get_time - start_time
    end

    def in_thread(*args, &block)
      @created_threads ||= Queue.new
      @created_threads.push t = Thread.new(*args, &block)
      t
    end

    def join_with(*threads, timeout: 0.1)
      Array(threads).each { |t| expect(t.join(timeout)).not_to eq nil }
    end
  end
end

class RSpec::Core::ExampleGroup
  include Concurrent::TestHelpers
  extend Concurrent::TestHelpers

  after :each do
    while (thread = (@created_threads.pop(true) rescue nil))
      thread.kill
      expect(thread.join(0.25)).not_to eq nil
    end
  end
end

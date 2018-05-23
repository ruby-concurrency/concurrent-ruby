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
      new_thread = Thread.new(*args) do |*args, &b|
        Thread.abort_on_exception = true
        block.call *args, &b
      end
      @created_threads.push new_thread
      new_thread
    end

    def join_with(threads, timeout = 5)
      threads = Array(threads)
      threads.each do |t|
        joined_thread = t.join(timeout * threads.size)
        expect(joined_thread).not_to eq nil
      end
    end
  end
end

class RSpec::Core::ExampleGroup
  include Concurrent::TestHelpers
  extend Concurrent::TestHelpers

  before :each do
    expect(@created_threads.nil? || @created_threads.empty?).to be_truthy
  end

  after :each do
    while (thread = (@created_threads.pop(true) rescue nil))
      thread.kill
      expect(thread.join(0.25)).not_to be_nil
    end
  end
end

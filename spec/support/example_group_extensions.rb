require 'rbconfig'
require 'concurrent/native_extensions'

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

    include EngineDetector

    def use_c_extensions?
      Concurrent.allow_c_extensions? # from extension_helper.rb
    end

    def do_no_reset!
      @do_not_reset = true
    end

    GLOBAL_EXECUTORS = [
      [:GLOBAL_FAST_EXECUTOR, ->{ Delay.new{ Concurrent.new_fast_executor }}],
      [:GLOBAL_IO_EXECUTOR, ->{ Delay.new{ Concurrent.new_io_executor }}],
      [:GLOBAL_TIMER_SET, ->{ Delay.new{ Concurrent::TimerSet.new }}],
    ]

    @@killed = false

    def reset_gem_configuration
      if @@killed
        GLOBAL_EXECUTORS.each do |var, factory|
          executor = Concurrent.const_get(var).value
          executor.shutdown
          executor.kill
          executor = nil
          Concurrent.const_set(var, factory.call)
        end
        @@killed = false
      end
    end

    def kill_rogue_threads(warning = true)
      return if @do_not_reset
      warn('[DEPRECATED] brute force thread control being used -- tests need updated') if warning
      Thread.list.each do |thread|
        thread.kill unless thread == Thread.current
      end
      @@killed = true
    end

    def monotonic_interval
      raise ArgumentError.new('no block given') unless block_given?
      start_time = GLOBAL_MONOTONIC_CLOCK.get_time
      yield
      GLOBAL_MONOTONIC_CLOCK.get_time - start_time
    end
  end
end

class RSpec::Core::ExampleGroup
  include Concurrent::TestHelpers
  extend Concurrent::TestHelpers
end

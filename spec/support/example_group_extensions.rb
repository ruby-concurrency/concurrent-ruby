require 'rbconfig'
require_relative '../../lib/extension_helper.rb'

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

    def mri?
      RUBY_ENGINE == 'ruby'
    end

    def jruby?
      RUBY_ENGINE == 'jruby'
    end

    def rbx?
      RUBY_ENGINE == 'rbx'
    end

    def use_c_extensions?
      Concurrent.allow_c_extensions? # from extension_helper.rb
    end

    def do_no_reset!
      @do_not_reset = true
    end

    GLOBAL_EXECUTORS = [
      [:@@global_fast_executor, ->{ LazyReference.new{ Concurrent.new_fast_executor }}],
      [:@@global_io_executor, ->{ LazyReference.new{ Concurrent.new_io_executor }}],
      [:@@global_timer_set, ->{ LazyReference.new{ Concurrent::TimerSet.new }}],
    ]

    @@killed = false

    def reset_gem_configuration
      if @@killed
        GLOBAL_EXECUTORS.each do |var, factory|
          executor = Concurrent.class_variable_get(var).value
          executor.shutdown
          executor.kill
          executor = nil
          Concurrent.class_variable_set(var, factory.call)
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

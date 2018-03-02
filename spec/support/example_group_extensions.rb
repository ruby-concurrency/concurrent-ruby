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
  end
end

class RSpec::Core::ExampleGroup
  include Concurrent::TestHelpers
  extend Concurrent::TestHelpers
end

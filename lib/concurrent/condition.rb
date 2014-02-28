module Concurrent
  class Condition

    class Result
      def initialize(remaining_time)
        @remaining_time = remaining_time
      end

      attr_reader :remaining_time

      def woken_up?
        @remaining_time.nil? || @remaining_time > 0
      end

      def timed_out?
        @remaining_time != nil && @remaining_time <= 0
      end

      alias_method :can_wait?, :woken_up?

    end

    def initialize
      @condition = ConditionVariable.new
    end

    def wait(mutex, timeout = nil)
      start_time = Time.now.to_f
      @condition.wait(mutex, timeout)

      if timeout.nil?
        Result.new(nil)
      else
        Result.new(start_time + timeout - Time.now.to_f)
      end
    end

    def signal
      @condition.signal
      true
    end

    def broadcast
      @condition.broadcast
      true
    end

  end
end
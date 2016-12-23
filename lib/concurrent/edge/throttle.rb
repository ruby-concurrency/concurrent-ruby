module Concurrent

  # A tool manage concurrency level of future tasks.
  # @example With futures
  #   data     = (1..5).to_a
  #   db       = data.reduce({}) { |h, v| h.update v => v.to_s }
  #   max_two = Promises.throttle 2
  #
  #   futures = data.map do |data|
  #     Promises.future(data) { |data|
  #       # un-throttled, concurrency level equal data.size
  #       data + 1
  #     }.then_throttle(max_two, db) { |v, db|
  #       # throttled, only 2 tasks executed at the same time
  #       # e.g. limiting access to db
  #       db[v]
  #     }
  #   end
  #
  #   futures.map(&:value!) # => [2, 3, 4, 5, nil]
  #
  # @example With Threads
  #   # TODO (pitr-ch 23-Dec-2016): thread example, add blocking block method for threads
  class Throttle < Synchronization::Object
    # TODO (pitr-ch 21-Dec-2016): consider using sized channel for implementation instead when available

    safe_initialization!
    private *attr_atomic(:can_run)

    # New throttle.
    # @param [Integer] limit
    def initialize(limit)
      super()
      @Limit       = limit
      self.can_run = limit
      @Queue       = LockFreeQueue.new
    end

    # @return [Integer] The limit.
    def limit
      @Limit
    end

    def trigger
      while true
        current_can_run = can_run
        if compare_and_set_can_run current_can_run, current_can_run - 1
          if current_can_run > 0
            return Promises.resolved_event
          else
            event = Promises.resolvable_event
            @Queue.push event
            return event
          end
        end
      end
    end

    def release
      while true
        current_can_run = can_run
        if compare_and_set_can_run current_can_run, current_can_run + 1
          if current_can_run < 0
            Thread.pass until (trigger = @Queue.pop)
            trigger.resolve
          end
          return self
        end
      end
    end

    # @return [String] Short string representation.
    def to_s
      format '<#%s:0x%x limit:%s can_run:%d>', self.class, object_id << 1, @Limit, can_run
    end

    alias_method :inspect, :to_s

    module PromisesIntegration

      def throttled(&throttled_futures)
        throttled_futures.call(trigger).on_resolution! { release }
      end

      def then_throttled(*args, &task)
        trigger.then(*args, &task).on_resolution! { release }
      end
    end

    include PromisesIntegration
  end

  module Promises

    class AbstractEventFuture < Synchronization::Object
      module ThrottleIntegration
        def throttled_by(throttle, &throttled_futures)
          a_trigger = throttle.trigger & self
          throttled_futures.call(a_trigger).on_resolution! { throttle.release }
        end

        def then_throttled_by(throttle, *args, &block)
          throttled_by(throttle) { |trigger| trigger.then(*args, &block) }
        end
      end

      include ThrottleIntegration
    end
  end
end

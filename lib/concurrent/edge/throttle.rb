module Concurrent
  # @!macro [new] throttle.example.throttled_block
  #   @example
  #     max_two = Throttle.new 2
  #     10.times.map do
  #       Thread.new do
  #         max_two.throttled_block do
  #           # Only 2 at the same time
  #           do_stuff
  #         end
  #       end
  #     end
  # @!macro [new] throttle.example.throttled_future
  #   @example
  #     throttle.throttled_future(1) do |arg|
  #       arg.succ
  #     end
  # @!macro [new] throttle.example.throttled_future_chain
  #   @example
  #     throttle.throttled_future_chain do |trigger|
  #       trigger.
  #           # 2 throttled promises
  #           chain { 1 }.
  #           then(&:succ)
  #     end
  # @!macro [new] throttle.example.then_throttled_by
  #   @example
  #     data     = (1..5).to_a
  #     db       = data.reduce({}) { |h, v| h.update v => v.to_s }
  #     max_two  = Throttle.new 2
  #
  #     futures = data.map do |data|
  #       Promises.future(data) do |data|
  #         # un-throttled, concurrency level equal data.size
  #         data + 1
  #       end.then_throttled_by(max_two, db) do |v, db|
  #         # throttled, only 2 tasks executed at the same time
  #         # e.g. limiting access to db
  #         db[v]
  #       end
  #     end
  #
  #     futures.map(&:value!) # => [2, 3, 4, 5, nil]

  # A tool manage concurrency level of future tasks.
  #
  # @!macro throttle.example.then_throttled_by
  # @!macro throttle.example.throttled_future
  # @!macro throttle.example.throttled_future_chain
  # @!macro throttle.example.throttled_block
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

    # New event which will be resolved when depending tasks can execute.
    # Has to be used and after the critical work is done {#release} must be called exactly once.
    # @return [Promises::Event]
    # @see #release
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

    # Has to be called once for each trigger after it is ok to execute another throttled task.
    # @return [self]
    # @see #trigger
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

    # Blocks current thread until the block can be executed.
    # @yield to throttled block
    # @yieldreturn [Object] is used as a result of the method
    # @return [Object] the result of the block
    # @!macro throttle.example.throttled_block
    def throttled_block(&block)
      trigger.wait
      block.call
    ensure
      release
    end

    # @return [String] Short string representation.
    def to_s
      format '<#%s:0x%x limit:%s can_run:%d>', self.class, object_id << 1, @Limit, can_run
    end

    alias_method :inspect, :to_s

    module PromisesIntegration

      # Allows to throttle a chain of promises.
      # @yield [trigger] a trigger which has to be used to build up a chain of promises, the last one is result
      #   of the block. When the last one resolves, {Throttle#release} is called on the throttle.
      # @yieldparam [Promises::Event, Promises::Future] trigger
      # @yieldreturn [Promises::Event, Promises::Future] The final future of the throttled chain.
      # @return [Promises::Event, Promises::Future] The final future of the throttled chain.
      # @!macro throttle.example.throttled_future_chain
      def throttled_future_chain(&throttled_futures)
        throttled_futures.call(trigger).on_resolution! { release }
      end

      # Behaves as {Promises::FactoryMethods#future} but the future is throttled.
      # @return [Promises::Future]
      # @see Promises::FactoryMethods#future
      # @!macro throttle.example.throttled_future
      def throttled_future(*args, &task)
        trigger.chain(*args, &task).on_resolution! { release }
      end
    end

    include PromisesIntegration
  end

  module Promises

    class AbstractEventFuture < Synchronization::Object
      module ThrottleIntegration
        def throttled_by(throttle, &throttled_futures)
          a_trigger = self & self.chain { throttle.trigger }.flat_event
          throttled_futures.call(a_trigger).on_resolution! { throttle.release }
        end

        # Behaves as {Promises::AbstractEventFuture#chain} but the it is throttled.
        # @return [Promises::Future, Promises::Event]
        # @see Promises::AbstractEventFuture#chain
        def chain_throttled_by(throttle, *args, &block)
          throttled_by(throttle) { |trigger| trigger.chain(*args, &block) }
        end
      end

      include ThrottleIntegration
    end

    class Future < AbstractEventFuture
      module ThrottleIntegration

        # Behaves as {Promises::Future#then} but the it is throttled.
        # @return [Promises::Future]
        # @see Promises::Future#then
        # @!macro throttle.example.then_throttled_by
        def then_throttled_by(throttle, *args, &block)
          throttled_by(throttle) { |trigger| trigger.then(*args, &block) }
        end

        # Behaves as {Promises::Future#rescue} but the it is throttled.
        # @return [Promises::Future]
        # @see Promises::Future#rescue
        def rescue_throttled_by(throttle, *args, &block)
          throttled_by(throttle) { |trigger| trigger.rescue(*args, &block) }
        end
      end

      include ThrottleIntegration
    end
  end
end

# TODO try stealing pool, each thread has it's own queue

require 'concurrent/promises'

module Concurrent
  module Promises

    class Future < AbstractEventFuture

      # @!macro warn.edge
      module ActorIntegration
        # Asks the actor with its value.
        # @return [Future] new future with the response form the actor
        def then_ask(actor)
          self.then(actor) { |v, a| a.ask_op(v) }.flat
        end
      end

      include ActorIntegration

      # @!macro warn.edge
      module FlatShortcuts

        # @return [Future]
        def then_flat_future(*args, &block)
          self.then(*args, &block).flat_future
        end

        alias_method :then_flat, :then_flat_future

        # @return [Future]
        def then_flat_future_on(executor, *args, &block)
          self.then_on(executor, *args, &block).flat_future
        end

        alias_method :then_flat_on, :then_flat_future_on

        # @return [Event]
        def then_flat_event(*args, &block)
          self.then(*args, &block).flat_event
        end

        # @return [Event]
        def then_flat_event_on(executor, *args, &block)
          self.then_on(executor, *args, &block).flat_event
        end
      end

      include FlatShortcuts
    end

    class Future < AbstractEventFuture
      # @!macro warn.edge
      module NewChannelIntegration

        # @param [Channel] channel to push to.
        # @return [Future] a future which is fulfilled after the message is pushed to the channel.
        #   May take a moment if the channel is full.
        def then_channel_push(channel)
          self.then(channel) { |value, ch| ch.push_op value }.flat_future
        end

      end

      include NewChannelIntegration
    end

    module FactoryMethods
      # @!macro promises.shortcut.on
      # @return [Future]
      # @!macro warn.edge
      def zip_futures_over(enumerable, &future_factory)
        zip_futures_over_on default_executor, enumerable, &future_factory
      end

      # Creates new future which is resolved after all the futures created by future_factory from
      # enumerable elements are resolved. Simplified it does:
      # `zip(*enumerable.map { |e| future e, &future_factory })`
      # @example
      #   # `#succ` calls are executed in parallel
      #   zip_futures_over_on(:io, [1, 2], &:succ).value! # => [2, 3]
      #
      # @!macro promises.param.default_executor
      # @param [Enumerable] enumerable
      # @yield a task to be executed in future
      # @yieldparam [Object] element from enumerable
      # @yieldreturn [Object] a value of the future
      # @return [Future]
      # @!macro warn.edge
      def zip_futures_over_on(default_executor, enumerable, &future_factory)
        # ZipFuturesPromise.new_blocked_by(futures_and_or_events, default_executor).future
        zip_futures_on(default_executor, *enumerable.map { |e| future e, &future_factory })
      end
    end

  end
end

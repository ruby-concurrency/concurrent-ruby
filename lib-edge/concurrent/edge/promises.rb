# TODO try stealing pool, each thread has it's own queue

require 'concurrent/promises'

module Concurrent
  module Promises

    class Future < AbstractEventFuture

      module ActorIntegration
        # Asks the actor with its value.
        # @return [Future] new future with the response form the actor
        def then_ask(actor)
          self.then { |v| actor.ask(v) }.flat
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

    class Channel < Concurrent::Synchronization::Object
      safe_initialization!

      # Default size of the Channel, makes it accept unlimited number of messages.
      UNLIMITED = ::Object.new
      UNLIMITED.singleton_class.class_eval do
        include Comparable

        def <=>(other)
          1
        end

        def to_s
          'unlimited'
        end
      end

      # A channel to pass messages between promises. The size is limited to support back pressure.
      # @param [Integer, UNLIMITED] size the maximum number of messages stored in the channel.
      def initialize(size = UNLIMITED)
        super()
        @Size        = size
        # TODO (pitr-ch 26-Dec-2016): replace with lock-free implementation
        @Mutex       = Mutex.new
        @Probes      = []
        @Messages    = []
        @PendingPush = []
      end


      # Returns future which will fulfill when the message is added to the channel. Its value is the message.
      # @param [Object] message
      # @return [Future]
      def push(message)
        @Mutex.synchronize do
          while true
            if @Probes.empty?
              if @Size > @Messages.size
                @Messages.push message
                return Promises.fulfilled_future message
              else
                pushed = Promises.resolvable_future
                @PendingPush.push [message, pushed]
                return pushed.with_hidden_resolvable
              end
            else
              probe = @Probes.shift
              if probe.fulfill [self, message], false
                return Promises.fulfilled_future(message)
              end
            end
          end
        end
      end

      # Returns a future witch will become fulfilled with a value from the channel when one is available.
      # @param [ResolvableFuture] probe the future which will be fulfilled with a channel value
      # @return [Future] the probe, its value will be the message when available.
      def pop(probe = Concurrent::Promises.resolvable_future)
        # TODO (pitr-ch 26-Dec-2016): improve performance
        pop_for_select(probe).then(&:last)
      end

      # @!visibility private
      def pop_for_select(probe = Concurrent::Promises.resolvable_future)
        @Mutex.synchronize do
          if @Messages.empty?
            @Probes.push probe
          else
            message = @Messages.shift
            probe.fulfill [self, message]

            unless @PendingPush.empty?
              message, pushed = @PendingPush.shift
              @Messages.push message
              pushed.fulfill message
            end
          end
        end
        probe
      end

      # @return [String] Short string representation.
      def to_s
        format '%s size:%s>', super[0..-2], @Size
      end

      alias_method :inspect, :to_s
    end

    class Future < AbstractEventFuture
      module NewChannelIntegration

        # @param [Channel] channel to push to.
        # @return [Future] a future which is fulfilled after the message is pushed to the channel.
        #   May take a moment if the channel is full.
        def then_push_channel(channel)
          self.then { |value| channel.push value }.flat_future
        end

      end

      include NewChannelIntegration
    end

    module FactoryMethods

      module NewChannelIntegration

        # Selects a channel which is ready to be read from.
        # @param [Channel] channels
        # @return [Future] a future which is fulfilled with pair [channel, message] when one of the channels is
        #   available for reading
        def select_channel(*channels)
          probe = Promises.resolvable_future
          channels.each { |ch| ch.pop_for_select probe }
          probe
        end
      end

      include NewChannelIntegration
    end

  end
end

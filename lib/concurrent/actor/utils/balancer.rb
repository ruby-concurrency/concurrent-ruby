module Concurrent
  module Actor
    module Utils

      # Distributes messages between subscribed actors. Each actor'll get only one message then
      # it's unsubscribed. The actor needs to resubscribe when it's ready to receive next message.
      # @see Pool
      class Balancer < RestartingContext

        def initialize
          @receivers = []
          @buffer    = []
        end

        def on_message(message)
          case message
          when :subscribe
            @receivers << envelope.sender
            distribute
            true
          when :unsubscribe
            @receivers.delete envelope.sender
            true
          when :subscribed?
            @receivers.include? envelope.sender
          else
            @buffer << message
            distribute
          end
        end

        def distribute
          while !@receivers.empty? && !@buffer.empty?
            @receivers.shift << @buffer.shift
          end
        end
      end
    end
  end
end

module Concurrent
  module Actor
    module Utils

      # Distributes messages between subscribed actors. Each actor'll get only one message then
      # it's unsubscribed. The actor needs to resubscribe when it's ready to receive next message.
      # It will buffer the messages if there is no worker registered.
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
            @buffer << envelope
            distribute
            Behaviour::MESSAGE_PROCESSED
          end
        end

        def distribute
          while !@receivers.empty? && !@buffer.empty?
            redirect @receivers.shift, @buffer.shift
          end
        end
      end
    end
  end
end

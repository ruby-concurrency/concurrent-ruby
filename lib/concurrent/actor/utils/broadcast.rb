require 'set'

module Concurrent
  module Actor
    module Utils
      class Broadcast < Context

        def initialize
          @receivers = Set.new
        end

        def on_message(message)
          case message
          when :subscribe
            @receivers.add envelope.sender
          when :unsubscribe
            @receivers.delete envelope.sender
          when :subscribed?
            @receivers.include? envelope.sender
          else
            @receivers.each { |r| r << message }
          end
        end

        # override to define different behaviour, filtering etc
        def receivers
          @receivers
        end
      end
    end
  end
end

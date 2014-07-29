require 'set'

module Concurrent
  module Actor
    module Utils

      # TODO doc
      class Broadcast < Context

        def initialize
          @receivers = Set.new
        end

        def on_message(message)
          case message
          when :subscribe
            @receivers.add envelope.sender
            true
          when :unsubscribe
            @receivers.delete envelope.sender
            true
          when :subscribed?
            @receivers.include? envelope.sender
          else
            filtered_receivers.each { |r| r << message }
          end
        end

        # override to define different behaviour, filtering etc
        def filtered_receivers
          @receivers
        end
      end
    end
  end
end

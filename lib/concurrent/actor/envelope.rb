module Concurrent
  module Actor
    class Envelope
      include TypeCheck

      # @!attribute [r] message
      #   @return [Object] a message
      # @!attribute [r] ivar
      #   @return [IVar] an ivar which becomes resolved after message is processed
      # @!attribute [r] sender
      #   @return [Reference, Thread] an actor or thread sending the message
      # @!attribute [r] address
      #   @return [Reference] where this message will be delivered

      attr_reader :message, :ivar, :sender, :address

      def initialize(message, ivar, sender, address)
        @message = message
        @ivar    = Type! ivar, IVar, NilClass
        @sender  = Type! sender, Reference, Thread
        @address = Type! address, Reference
      end

      def sender_path
        if sender.is_a? Reference
          sender.path
        else
          sender.to_s
        end
      end

      def address_path
        address.path
      end

      def reject!(error)
        ivar.fail error unless ivar.nil?
      end
    end
  end
end

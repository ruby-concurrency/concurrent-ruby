module Concurrent
  module Actress
    Envelope = Struct.new :message, :ivar, :sender do
      include TypeCheck

      def initialize(message, ivar, sender)
        super message,
              (Type! ivar, IVar, NilClass),
              (Type! sender, Reference, Thread)
      end

      def sender_path
        if sender.is_a? Reference
          sender.path
        else
          sender.to_s
        end
      end

      def reject!(error)
        ivar.fail error unless ivar.nil?
      end
    end
  end
end

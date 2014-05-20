module Concurrent
  module Actress
    class AdHoc
      include Context
      def initialize(&initializer)
        @on_message = Type! initializer.call, Proc
      end

      def on_message(message)
        @on_message.call message
      end
    end
  end
end

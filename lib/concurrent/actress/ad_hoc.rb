module Concurrent
  module Actress
    class AdHoc
      include Context
      def initialize(*args, &initializer)
        @on_message = Type! initializer.call(*args), Proc
      end

      def on_message(message)
        instance_exec message, &@on_message
      end
    end
  end
end

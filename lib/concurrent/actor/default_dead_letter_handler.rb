module Concurrent
  module Actor
    class DefaultDeadLetterHandler < Context
      def on_message(dead_letter)
        log Logging::INFO, "got dead letter #{dead_letter.inspect}"
      end
    end
  end
end

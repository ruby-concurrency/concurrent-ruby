module Concurrent
  module Actor
    class DefaultDeadLetterHandler < RestartingContext
      def on_message(dead_letter)
        log Logging::INFO, "got dead letter #{dead_letter.inspect}"
      end
    end
  end
end

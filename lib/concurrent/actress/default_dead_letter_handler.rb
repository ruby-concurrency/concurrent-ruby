module Concurrent
  module Actress
    class DefaultDeadLetterHandler
      include Context

      def on_message(dead_letter)
        log Logging::WARN, "got dead letter #{dead_letter.inspect}"
      end
    end
  end
end

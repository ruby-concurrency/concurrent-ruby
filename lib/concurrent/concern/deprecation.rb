require 'concurrent/concern/logging'

module Concurrent
  module Concern

    # @api private
    module Deprecation
      # TODO require additional parameter: a version. Display when it'll be removed based on that. Error if not removed.
      include Concern::Logging

      def deprecated(message, strip = 2)
        caller_line = caller(strip).first
        klass       = if Class === self
                        self
                      else
                        self.class
                      end
        log WARN, klass.to_s, format("[DEPRECATED] %s\ncalled on: %s", message, caller_line)
      end

      def deprecated_method(old_name, new_name)
        deprecated "`#{old_name}` is deprecated and it'll removed in next release, use `#{new_name}` instead", 3
      end
    end
  end
end

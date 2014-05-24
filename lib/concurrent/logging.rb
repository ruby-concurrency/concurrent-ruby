require 'logger'

module Concurrent
  module Logging
    include Logger::Severity

    def log(level, progname, message = nil, &block)
      (@logger || Concurrent.configuration.logger).call level, progname, message, &block
    end
  end
end

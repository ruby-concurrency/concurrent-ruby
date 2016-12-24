require 'concurrent/concern/logging'

module Concurrent
  module Utility
    # Provides common logic for handling System exceptions (at places, where `rescue => Exception` is needed)
    #
    # @!visibility private
    class SystemExceptionsHandler
      UNHANDLED_EXCEPTIONS = [SystemExit, SystemStackError, NoMemoryError]
      class << self
        include Concern::Logging

        # Logs an exception an and re-raises if it's not wise to rescue from it.
        #
        # @example by class and name
        #   rescue Exception => error
        #     Utility::SystemExceptionsHandler.handle(error, 'Worker task error')
        #     # ... some other logic if the error was rescued
        #
        # @!visibility private
        def handle(error, context_message)
          if !error.is_a?(StandardError) && UNHANDLED_EXCEPTIONS.any? { |klass| error.is_a?(klass) }
            raise error
          else
            log(ERROR, context_message, error)
          end
        end
      end
    end
  end
end

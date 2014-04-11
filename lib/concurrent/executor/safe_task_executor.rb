module Concurrent

  # A simple utility class that executes a callable and returns and array of three elements:
  # success - indicating if the callable has been executed without errors
  # value - filled by the callable result if it has been executed without errors, nil otherwise
  # reason - the error risen by the callable if it has been executed with errors, nil otherwise
  class SafeTaskExecutor
    def initialize(task)
      @task = task
    end

    # @return [Array]
    def execute
      success = false
      value = reason = nil

      begin
        value = @task.call
        success = true
      rescue => ex
        reason = ex
        success = false
      end

      [success, value, reason]
    end
  end
end
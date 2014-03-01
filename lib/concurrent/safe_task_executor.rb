module Concurrent
  class SafeTaskExecutor
    def initialize(task)
      @task = task
    end

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
module Concurrent

  # Ensures that jobs are passed to the given executors one by one,
  # never running at the same time.
  class OneByOne

    Job = Struct.new(:executor, :args, :block) do
      def call
        block.call *args
      end
    end

    def initialize
      @being_executed = false
      @stash          = []
      @mutex          = Mutex.new
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Executor] executor to be used for this job
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] `true` if the task is queued, `false` if the executor
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(executor, *args, &task)
      return nil if task.nil?
      job = Job.new executor, args, task

      begin
        @mutex.lock
        post = if @being_executed
                 @stash << job
                 false
               else
                 @being_executed = true
               end
      ensure
        @mutex.unlock
      end

      call_job job if post
      true
    end

    private

    def call_job(job)
      job.executor.post { work(job) }
    end

    # ensures next job is executed if any is stashed
    def work(job)
      job.call
    ensure
      begin
        @mutex.lock
        job = @stash.shift || (@being_executed = false)
      ensure
        @mutex.unlock
      end

      call_job job if job
    end

  end
end

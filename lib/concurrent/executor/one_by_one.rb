module Concurrent

  # Ensures that jobs are passed to the underlying executor one by one,
  # never running at the same time.
  class OneByOne

    attr_reader :executor

    Job = Struct.new(:args, :block) do
      def call
        block.call *args
      end
    end

    # @param [Executor] executor
    def initialize(executor)
      @executor       = executor
      @being_executed = false
      @stash          = []
      @mutex          = Mutex.new
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] `true` if the task is queued, `false` if the executor
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(*args, &task)
      return nil if task.nil?
      job = Job.new args, task
      @mutex.lock
      post = if @being_executed
               @stash << job
               false
             else
               @being_executed = true
             end
      @mutex.unlock
      @executor.post { work(job) } if post
      true
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Proc] task the asynchronous task to perform
    #
    # @return [self] returns itself
    def <<(task)
      post(&task)
      self
    end

    private

    # ensures next job is executed if any is stashed
    def work(job)
      job.call
    ensure
      @mutex.lock
      job = @stash.shift || (@being_executed = false)
      @mutex.unlock
      @executor.post { work(job) } if job
    end

  end
end

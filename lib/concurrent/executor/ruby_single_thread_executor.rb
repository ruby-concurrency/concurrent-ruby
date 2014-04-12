require_relative 'executor'

module Concurrent

  # @!macro single_thread_executor
  class RubySingleThreadExecutor
    include Executor

    # Create a new thread pool.
    #
    # @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    def initialize(opts = {})
      @queue = Queue.new
      @thread = nil
      init_executor
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    def shutdown
      mutex.synchronize do
        return unless running?
        stop_event.set
        @queue << :stop
        stopped_event.set unless alive?
      end
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
      mutex.synchronize do
        return if shutdown?
        stop_event.set
        @queue.clear
        @thread.kill if alive?
        stopped_event.set unless alive?
      end
    end

    protected

    def execute(*args, &task)
      supervise
      @queue << [args, task]
    end

    def alive?
      @thread && @thread.alive?
    end

    def supervise
      @thread = new_worker_thread unless alive?
    end

    def new_worker_thread
      Thread.new do
        Thread.current.abort_on_exception = false
        work
      end
    end

    def work
      loop do
        task = @queue.pop
        break if task == :stop
        begin
          task.last.call(*task.first)
        rescue => ex
          # let it fail
        end
      end
      stopped_event.set
    end
  end
end

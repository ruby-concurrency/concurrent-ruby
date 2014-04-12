require 'thread'

require_relative 'executor'
require 'concurrent/atomic/event'

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
      @mutex = Mutex.new
      @queue = Queue.new
      @thread = nil
      @stop = Event.new
      @stopped = Event.new
    end

    # Is the thread pool running?
    #
    # @return [Boolean] `true` when running, `false` when shutting down or shutdown
    def running?
      ! @stop.set?
    end

    # Is the thread pool shutdown?
    #
    # @return [Boolean] `true` when shutdown, `false` when shutting down or running
    def shutdown?
      @stopped.set?
    end

    # Block until thread pool shutdown is complete or until `timeout` seconds have
    # passed.
    #
    # @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] `true` if shutdown complete or false on `timeout`
    def wait_for_termination(timeout)
      @stopped.wait(timeout.to_i)
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] `true` if the task is queued, `false` if the thread pool
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      @mutex.synchronize do
        break false unless running?
        supervise
        @queue << [args, task]
        true
      end
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    def shutdown
      @mutex.synchronize do
        return unless running?
        @stop.set
        @queue << :stop
        @stopped.set unless alive?
      end
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
      @mutex.synchronize do
        return if shutdown?
        @stop.set
        @queue.clear
        @thread.kill if alive?
        @stopped.set
      end
    end

    protected

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
      @stopped.set
    end
  end
end

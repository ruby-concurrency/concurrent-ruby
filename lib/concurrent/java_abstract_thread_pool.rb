if defined? java.util

  module Concurrent

    # @!macro cached_thread_pool
    module JavaAbstractThreadPool

      # Is the thread pool running?
      #
      # @return [Boolean] +true+ when running, +false+ when shutting down or shutdown
      def running?
        ! (shutdown? || terminated?)
      end

      # Is the thread pool shutdown?
      #
      # @return [Boolean] +true+ when shutdown, +false+ when shutting down or running
      def shutdown?
        @executor.isShutdown
      end

      # Were all tasks completed before shutdown?
      #
      # @return [Boolean] +true+ if shutdown and all tasks completed else +false+
      def terminated?
        @executor.isTerminated
      end

      # Block until thread pool shutdown is complete or until +timeout+ seconds have
      # passed.
      #
      # @note Does not initiate shutdown or termination. Either +shutdown+ or +kill+
      #   must be called before this method (or on another thread).
      #
      # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
      #
      # @return [Boolean] +true+ if shutdown complete or false on +timeout+
      def wait_for_termination(timeout)
        @executor.awaitTermination(timeout.to_i, java.util.concurrent.TimeUnit::SECONDS)
      end

      # Submit a task to the thread pool for asynchronous processing.
      #
      # @param [Array] args zero or more arguments to be passed to the task
      #
      # @yield the asynchronous task to perform
      #
      # @return [Boolean] +true+ if the task is queued, +false+ if the thread pool
      #   is not running
      #
      # @raise [ArgumentError] if no task is given
      def post(*args)
        raise ArgumentError.new('no block given') unless block_given?
        @executor.submit{ yield(*args) }
        return true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        return false
      end

      # Submit a task to the thread pool for asynchronous processing.
      #
      # @param [Proc] task the asynchronous task to perform
      #
      # @return [self] returns itself
      def <<(task)
        @executor.submit(&task)
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        # do nothing
      ensure
        return self
      end

      # Begin an orderly shutdown. Tasks already in the queue will be executed,
      # but no new tasks will be accepted. Has no additional effect if the
      # thread pool is not running.
      def shutdown
        @executor.shutdown
        return nil
      end

      # Begin an immediate shutdown. In-progress tasks will be allowed to
      # complete but enqueued tasks will be dismissed and no new tasks
      # will be accepted. Has no additional effect if the thread pool is
      # not running.
      def kill
        @executor.shutdownNow
        return nil
      end

      # The number of threads currently in the pool.
      #
      # @return [Integer] a non-zero value when the pool is running,
      #   zero when the pool is shutdown
      def length
        running? ? 1 : 0
      end
      alias_method :size, :length
    end
  end
end

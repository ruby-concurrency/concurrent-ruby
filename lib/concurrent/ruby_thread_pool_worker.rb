require 'thread'

module Concurrent

  # @!visibility private
  class RubyThreadPoolWorker # :nodoc:

    # @!visibility private
    def initialize(queue, parent) # :nodoc:
      @queue = queue
      @parent = parent
      @mutex = Mutex.new
      @last_activity = Time.now.to_f
    end

    # @!visibility private
    def dead? # :nodoc:
      return @mutex.synchronize do
        @thread.nil? ? false : ! @thread.alive?
      end
    end

    # @!visibility private
    def last_activity # :nodoc:
      @mutex.synchronize { @last_activity }
    end

    def status
      @mutex.synchronize do
        return 'not running' if @thread.nil?
        @thread.status
      end
    end

    # @!visibility private
    def kill # :nodoc:
      @mutex.synchronize do
        Thread.kill(@thread) unless @thread.nil?
        @thread = nil
      end
    end

    # @!visibility private
    def run(thread = Thread.current) # :nodoc:
      @mutex.synchronize do
        raise StandardError.new('already running') unless @thread.nil?
        @thread = thread
      end

      loop do
        task = @queue.pop
        if task == :stop
          @thread = nil
          @parent.on_worker_exit(self)
          break
        end

        begin
          task.last.call(*task.first)
        rescue => ex
          # let it fail
        ensure
          @last_activity = Time.now.to_f
          @parent.on_end_task
        end
      end
    end
  end
end

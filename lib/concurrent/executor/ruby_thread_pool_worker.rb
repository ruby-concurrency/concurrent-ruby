require 'thread'
require 'concurrent/logging'

module Concurrent

  # @!visibility private
  class RubyThreadPoolWorker
    include Logging

    # @!visibility private
    def initialize(queue, parent)
      @queue = queue
      @parent = parent
      @mutex = Mutex.new
      @last_activity = Time.now.to_f
      @thread = nil
    end

    # @!visibility private
    def dead?
      return @mutex.synchronize do
        @thread.nil? ? false : ! @thread.alive?
      end
    end

    # @!visibility private
    def last_activity
      @mutex.synchronize { @last_activity }
    end

    def status
      @mutex.synchronize do
        return 'not running' if @thread.nil?
        @thread.status
      end
    end

    # @!visibility private
    def kill
      @mutex.synchronize do
        Thread.kill(@thread) unless @thread.nil?
        @thread = nil
      end
    end

    # @!visibility private
    def run(thread = Thread.current)
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
          log DEBUG, ex
        ensure
          @last_activity = Time.now.to_f
          @parent.on_end_task
        end
      end
    end
  end
end

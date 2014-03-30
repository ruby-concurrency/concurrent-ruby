require 'thread'

module Concurrent

  class RubyThreadPoolExecutor

    class Worker

      def initialize(queue, parent)
        @queue = queue
        @parent = parent
        @mutex = Mutex.new
        @last_activity = Time.now.to_i
      end

      def dead?
        return @mutex.synchronize do
          @thread.nil? ? false : ! @thread.alive?
        end
      end

      def last_activity
        @mutex.synchronize { @last_activity }
      end

      def kill
        @mutex.synchronize do
          Thread.kill(@thread) unless @thread.nil?
          @thread = nil
        end
      end

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
            #@parent.on_start_task
            task.last.call(*task.first)
          rescue => ex
            # let it fail
          ensure
            @last_activity = Time.now.to_i
            @parent.on_end_task
          end
        end
      end
    end
  end
end

require 'thread'

module Concurrent

  class FixedThreadPool

    class Worker

      def initialize(queue, parent)
        @queue = queue
        @parent = parent
        @mutex = Mutex.new
      end

      def dead?
        return @mutex.synchronize do
          @thread.nil? ? false : ! @thread.alive?
        end
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

          @parent.on_start_task(self)
          begin
            task.last.call(*task.first)
          rescue
            # let it fail
          ensure
            @parent.on_end_task(self)
          end
        end
      end
    end
  end
end

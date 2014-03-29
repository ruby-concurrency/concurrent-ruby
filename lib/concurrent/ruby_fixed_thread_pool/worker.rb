require 'thread'

module Concurrent

  class RubyFixedThreadPool

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

          begin
            task.last.call(*task.first)
          rescue => ex
            # let it fail
          ensure
            @parent.on_end_task(self, ex.nil?)
          end
        end
      end
    end
  end
end

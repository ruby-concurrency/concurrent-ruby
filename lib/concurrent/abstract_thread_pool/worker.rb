require 'thread'

module Concurrent

  class AbstractThreadPool

    class Worker

      def initialize(queue, parent)
        @queue = queue
        @parent = parent
        @mutex = Mutex.new
        @idletime = Time.now
      end
     
      def idle?
        return ! @idletime.nil?
      end

      def dead?
        return @mutex.synchronize do
          @thread.nil? ? false : ! @thread.alive?
        end
      end

      def idletime
        return @mutex.synchronize do
          @idletime.nil? ? 0 : Time.now.to_i - @idletime.to_i
        end
      end

      def status
        return @mutex.synchronize do
          [
            @idletime,
            @thread.nil? ? false : @thread.status
          ]
        end
      end

      def kill
        @mutex.synchronize do
          Thread.kill(@thread) unless @thread.nil?
          @thread = nil
          @idletime = Time.now
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

          @idletime = nil
          Worker.busy
          @parent.on_start_task(self)
          begin
            task.last.call(*task.first)
          rescue
            # let it fail
          ensure
            Worker.free
            @idletime = Time.now
            @parent.on_end_task(self)
          end
        end
      end

      class << self
        attr_reader :working

        def mutex
          @working ||= 0
          @mutex ||= Mutex.new
        end

        def busy
          mutex.synchronize { @working += 1 }
        end

        def free
          mutex.synchronize { @working -= 1 }
        end
      end
    end
  end
end

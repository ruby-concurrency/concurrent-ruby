require 'thread'

module Concurrent

  class RubyCachedThreadPool

    class Worker

      def initialize(parent)
        @parent = parent
        @mutex = Mutex.new
        @idletime = Time.now
        @resource = ConditionVariable.new
        @tasks = Queue.new
      end

      def tasks_remaining?
        return @mutex.synchronize do
          ! @tasks.empty?
        end
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

      def signal(*args, &block)
        return @mutex.synchronize do
          break(false) if @parent.nil?
          @tasks << [args, block]
          @resource.signal
          true
        end
      end

      def stop
        return @mutex.synchronize do
          @tasks.clear
          @tasks << :stop
          @resource.signal
        end
      end

      def kill
        @mutex.synchronize do
          @idletime = Time.now
          @parent = nil
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
          task = @mutex.synchronize do
            @resource.wait(@mutex, 60) if @tasks.empty?
            @tasks.pop(true)
          end

          if task == :stop
            @thread = nil
            @parent.on_worker_exit(self)
            @parent = nil
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

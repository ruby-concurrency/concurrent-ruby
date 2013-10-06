require 'thread'
require 'observer'

require 'concurrent/runnable'

module Concurrent

  class Channel
    include Observable
    include Runnable
    behavior(:runnable)

    def initialize(errorback = nil, &block)
      @queue = Queue.new
      @task = block
      @errorback = errorback
    end

    def post(*message)
      return false unless running?
      @queue.push(message)
      return @queue.length
    end

    def <<(message)
      post(*message)
      return self
    end

    def self.pool(count, errorback = nil, &block)
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      channels = count.times.collect do
        channel = self.new(errorback, &block)
        channel.instance_variable_set(:@queue, mailbox)
        channel
      end
      return Poolbox.new(mailbox), channels
    end

    protected

    class Poolbox

      def initialize(queue)
        @queue = queue
      end

      def post(*message)
        @queue.push(message)
        return @queue.length
      end

      def <<(message)
        post(*message)
        return self
      end
    end

    # @private
    def on_run # :nodoc:
      @queue.clear
    end

    # @private
    def on_stop # :nodoc:
      @queue.clear
      @queue.push(:stop)
    end

    # @private
    def on_task # :nodoc:
      message = @queue.pop
      return if message == :stop
      begin
        result = receive(*message)
        changed
        notify_observers(Time.now, message, result)
      rescue => ex
        on_error(Time.now, message, ex)
      end
    end

    # @private
    def on_error(time, msg, ex) # :nodoc:
      @errorback.call(time, msg, ex) if @errorback
    end

    # @private
    def receive(*message) # :nodoc:
      @task.call(*message) unless @task.nil?
    end
  end
end

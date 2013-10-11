require 'thread'
require 'observer'

require 'concurrent/runnable'

module Concurrent

  # http://www.scala-lang.org/api/current/index.html#scala.actors.Actor
  class Actor
    include Observable
    include Runnable

    def initialize
      @queue = Queue.new
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

    def self.pool(count, &block)
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      channels = count.times.collect do
        channel = self.new(&block)
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
    end
  end
end

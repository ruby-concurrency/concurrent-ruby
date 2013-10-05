require 'thread'
require 'observer'

require 'concurrent/runnable'

module Concurrent

  class Channel
    include Observable
    include Runnable
    behavior(:runnable)

    def initialize(errorback = nil, &block)
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

    protected

    # @private
    def on_run # :nodoc:
      @queue = Queue.new
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

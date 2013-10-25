require 'thread'
require 'observer'

require 'concurrent/runnable'
require 'concurrent/obligation'

module Concurrent

  module Postable

    def post(*message)
      return false if self.respond_to?(:running?) && ! running?
      queue.push([message, nil])
      return queue.length
    end

    def <<(message)
      post(*message)
      return self
    end

    def post!(*message)
      contract = Contract.new
      queue.push([message, contract])
      return contract
    end

    private

    def queue
      @queue ||= Queue.new
    end
  end

  class Actor
    include Observable
    include Runnable
    include Postable

    class Poolbox
      include Postable

      def initialize(queue)
        @queue = queue
      end
    end

    def self.pool(count, &block)
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      actors = count.times.collect do
        actor = self.new(&block)
        actor.instance_variable_set(:@queue, mailbox)
        actor
      end
      return Poolbox.new(mailbox), actors
    end

    protected

    def act(*args)
      raise NotImplementedError.new("#{self.class} does not implement #act")
    end

    # @private
    def on_run # :nodoc:
      queue.clear
    end

    # @private
    def on_stop # :nodoc:
      queue.clear
      queue.push(:stop)
    end

    # @private
    def on_task # :nodoc:
      message = queue.pop
      return if message == :stop
      begin
        result = act(*message.first)
        message.last.complete(result, nil) if message.last
        changed
        notify_observers(Time.now, message.first, result)
      rescue => ex
        message.last.complete(nil, ex) if message.last
        on_error(Time.now, message.first, ex)
      end
    end

    # @private
    def on_error(time, msg, ex) # :nodoc:
    end
  end
end

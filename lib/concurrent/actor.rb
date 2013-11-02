require 'thread'
require 'observer'

require 'concurrent/event'
require 'concurrent/obligation'
require 'concurrent/runnable'

module Concurrent

  module Postable

    Package = Struct.new(:message, :handler, :notifier)

    def post(*message)
      return false unless ready?
      queue.push(Package.new(message))
      return queue.length
    end

    def <<(message)
      post(*message)
      return self
    end

    def post!(*message)
      #return nil unless ready?
      contract = Contract.new
      queue.push(Package.new(message, contract))
      return contract
    end

    def post?(seconds, *message)
      #raise Concurrent::Runnable::LifecycleError unless ready?
      raise Concurrent::TimeoutError if seconds.to_f <= 0.0
      event = Event.new
      cback = Queue.new
      queue.push(Package.new(message, cback, event))
      if event.wait(seconds)
        result = cback.pop
        if result.is_a?(Exception)
          raise result
        else
          return result
        end
      else
        event.set # attempt to cancel
        raise Concurrent::TimeoutError
      end
    end

    def forward(receiver, *message)
      #return false unless ready?
      queue.push(Package.new(message, receiver))
      return queue.length
    end

    def ready?
      if self.respond_to?(:running?) && ! running?
        return false
      else
        return true
      end
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
      package = queue.pop
      return if package == :stop
      result = ex = nil
      notifier = package.notifier
      begin
        if notifier.nil? || (notifier.is_a?(Event) && ! notifier.set?)
          result = act(*package.message)
        end
      rescue => ex
        on_error(Time.now, package.message, ex)
      ensure
        if package.handler.is_a?(Contract)
          package.handler.complete(result, ex)
        elsif notifier.is_a?(Event) && ! notifier.set?
          package.handler.push(result || ex)
          package.notifier.set
        elsif package.handler.is_a?(Actor) && ex.nil?
          package.handler.post(result)
        end

        changed
        notify_observers(Time.now, package.message, result, ex)
      end
    end

    # @private
    def on_error(time, msg, ex) # :nodoc:
    end
  end
end

require 'thread'
require 'observer'

require 'concurrent/event'
require 'concurrent/obligation'
require 'concurrent/postable'
require 'concurrent/runnable'

module Concurrent

  # @!parse include Observable
  # @!parse include Postable
  # @!parse include Runnable
  class Actor
    include Observable
    include Postable
    include Runnable

    private

    # @api private
    class Poolbox # :nodoc:
      include Postable

      def initialize(queue)
        @queue = queue
      end
    end

    public

    def self.pool(count, *args)
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      actors = count.times.collect do
        actor = self.new(*args)
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

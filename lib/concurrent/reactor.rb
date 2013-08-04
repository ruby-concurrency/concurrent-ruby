require 'thread'

module Concurrent

  class Reactor

    RESERVED_EVENTS = [ :stop ]

    EventContext = Struct.new(:event, :args, :callback)

    def initialize(demux = nil)
      @running = false
      @queue = Queue.new
      @handlers = Hash.new
    end

    def add_handler(event, &block)
      event = event.to_sym
      raise ArgumentError.new("'#{event}' is a reserved event") if RESERVED_EVENTS.include?(event)
      raise ArgumentError.new('no block given') unless block_given?
      @handlers[event] = block
      return true
    end

    def remove_handler(event)
      return ! @handlers.delete(event.to_sym).nil?
    end

    def stop_on_signal(*signals)
      signals.each{|signal| Signal.trap(signal){ self.stop } }
    end

    def handle(event, *args)
      context = EventContext.new(event.to_sym, args.dup, Queue.new)
      @queue.push(context)
      return context.callback.pop
    end

    def running?
      return @running
    end

    def start
      raise StandardError.new('already running') if self.running?
      @running = true
      run
    end

    def stop
      return unless self.running?
      @queue.push(:stop)
      return nil
    end

    private

    def run
      loop do
        context = @queue.pop
        break if context == :stop
        handler = @handlers[context.event]
        if handler.nil?
          context.callback.push([:noop, 'handler not found'])
        else
          begin
            result = handler.call(*context.args)
            context.callback.push([:ok, result])
          rescue Exception => ex
            context.callback.push([:ex, ex])
          end
        end
      end
      @running = false
    end
  end
end

require 'thread'
require 'functional'

behavior_info(:sync_event_demux,
              start: 0,
              stop: 0,
              stopped?: 0,
              accept: 0,
              respond: 2)

behavior_info(:async_event_demux,
              start: 0,
              stop: 0,
              stopped?: 0,
              set_reactor: 1)

behavior_info(:demux_reactor,
              handle: -2)

module Concurrent

  class Reactor

    behavior(:demux_reactor)

    RESERVED_EVENTS = [ :stop ]

    EventContext = Struct.new(:event, :args, :callback)

    def initialize(demux = nil)
      @demux = demux
      if @demux.nil? || @demux.behaves_as?(:async_event_demux)
        @sync = false
        @queue = Queue.new
        @demux.set_reactor(self) unless @demux.nil?
      elsif @demux.behaves_as?(:sync_event_demux)
        @sync = true
      else
        raise ArgumentError.new("invalid event demultiplexer '#{@demux}'")
      end

      @running = false
      @handlers = Hash.new
      @mutex = Mutex.new
    end

    def running?
      return @running
    end

    def add_handler(event, &block)
      raise ArgumentError.new('no block given') unless block_given?
      event = event.to_sym
      raise ArgumentError.new("'#{event}' is a reserved event") if RESERVED_EVENTS.include?(event)
      @mutex.synchronize {
        @handlers[event] = block
      }
      return true
    end

    def remove_handler(event)
      handler = @mutex.synchronize {
        @handlers.delete(event.to_sym)
      }
      return ! handler.nil?
    end

    def stop_on_signal(*signals)
      signals.each{|signal| Signal.trap(signal){ Thread.new{ self.stop }}}
    end

    def handle(event, *args)
      raise NotImplementedError.new("demultiplexer '#{@demux.class}' is synchronous") if @sync 
      return [:stopped, 'reactor not running'] unless running?
      context = EventContext.new(event.to_sym, args.dup, Queue.new)
      @queue.push(context)
      return context.callback.pop
    end

    def start
      raise StandardError.new('already running') if self.running?
      @sync ? (@running = true; run_sync) : (@running = true; run_async)
    end
    alias_method :run, :start

    def stop
      return true unless self.running?
      if @sync
        @demux.stop
      else
        @queue.push(:stop)
      end
      return true
    end

    private

    def handle_event(context)
      raise ArgumentError.new('no block given') unless block_given?

      handler = @mutex.synchronize {
        @handlers[context.event]
      }

      if handler.nil?
        response = yield(:noop, "'#{context.event}' handler not found")
      else
        begin
          result = handler.call(*context.args)
          response = yield(:ok, result)
        rescue Exception => ex
          response = yield(:ex, ex)
        end
      end

      return response
    end

    def finalize_stop
      @mutex.synchronize do
        @running = false
        @demux.stop unless @demux.nil?
        @demux = nil
      end
    end

    def run_sync
      @demux.start

      loop do
        break if @demux.stopped?
        context = @demux.accept
        if context.nil?
          @demux.close
        else
          response = handle_event(context) do |result, message|
            [result, message]
          end
          @demux.respond(*response)
        end
      end

      finalize_stop
    end

    def run_async
      @demux.start unless @demux.nil?

      loop do
        context = @queue.pop
        break if context == :stop
        handle_event(context) do |result, message|
          context.callback.push([result, message])
        end
      end

      finalize_stop
    end
  end
end

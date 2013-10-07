require 'thread'
require 'functional'

require 'concurrent/runnable'

behavior_info(:sync_event_demux,
              run: 0,
              stop: 0,
              running?: 0,
              accept: 0,
              respond: 2)

behavior_info(:async_event_demux,
              run: 0,
              stop: 0,
              running?: 0,
              set_reactor: 1)

behavior_info(:demux_reactor,
              handle: -2)

module Concurrent

  class Reactor
    include Runnable
    behavior(:demux_reactor)
    behavior(:runnable)

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

      @handlers = Hash.new
    end

    def add_handler(event, &block)
      mutex.synchronize {
        raise ArgumentError.new('no block given') unless block_given?
        event = event.to_sym
        raise ArgumentError.new("'#{event}' is a reserved event") if RESERVED_EVENTS.include?(event)
        @handlers[event] = block
      }
      return true
    end

    def remove_handler(event)
      handler = mutex.synchronize {
        @handlers.delete(event.to_sym)
      }
      return ! handler.nil?
    end

    def stop_on_signal(*signals)
      signals.each do |signal|
        Signal.trap(signal) do
          Thread.new do
            Thread.current.abort_on_exception = false
            self.stop
          end
        end
      end
    end

    def handle(event, *args)
      raise NotImplementedError.new("demultiplexer '#{@demux.class}' is synchronous") if @sync 
      return [:stopped, 'reactor not running'] unless running?
      context = EventContext.new(event.to_sym, args.dup, Queue.new)
      @queue.push(context)
      return context.callback.pop
    end

    protected

    def on_run
      @demux.run unless @demux.nil?
    end

    def on_stop
      if @sync
        @demux.stop
      else
        @queue.push(:stop)
      end
    end

    def on_task
      @sync ? run_sync : run_async
    end

    def handle_event(context)
      raise ArgumentError.new('no block given') unless block_given?

      handler = mutex.synchronize {
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

    def after_stop
      mutex.synchronize do
        @demux.stop unless @demux.nil?
        @demux = nil
      end
    end

    def run_sync
      return unless @demux.running?
      context = @demux.accept
      if context.nil?
        @demux.stop
      else
        response = handle_event(context) do |result, message|
          [result, message]
        end
        @demux.respond(*response)
      end
    rescue Exception => ex
      @demux.respond(:abend, ex)
    end

    def run_async
      context = @queue.pop
      return if context == :stop
      handle_event(context) do |result, message|
        context.callback.push([result, message])
      end
    end
  end
end

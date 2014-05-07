require 'concurrent/actor/actor_ref'
require 'concurrent/atomic/event'
require 'concurrent/executor/single_thread_executor'
require 'concurrent/ivar'

module Concurrent

  class SimpleActorRef
    include ActorRef

    def initialize(actor, opts = {})
      @actor = actor
      @mutex = Mutex.new
      @executor = OneByOne.new OptionsParser::get_executor_from(opts)
      @stop_event = Event.new
      @reset_on_error = opts.fetch(:reset_on_error, true)
      @exception_class = opts.fetch(:rescue_exception, false) ? Exception : StandardError
      @args = opts.fetch(:args, []) if @reset_on_error

      @actor.define_singleton_method(:shutdown, &method(:set_stop_event))
      @actor.on_start
    end

    def running?
      ! @stop_event.set?
    end

    def shutdown?
      @stop_event.set?
    end

    def post(*msg, &block)
      raise ArgumentError.new('message cannot be empty') if msg.empty?
      ivar = IVar.new
      @executor.post(Message.new(msg, ivar, block), &method(:process_message))
      ivar
    end

    def post!(timeout, *msg)
      raise Concurrent::TimeoutError unless timeout.nil? || timeout >= 0
      ivar = self.post(*msg)
      ivar.value(timeout)
      if ivar.incomplete?
        raise Concurrent::TimeoutError
      elsif ivar.reason
        raise ivar.reason
      end
      ivar.value
    end

    def shutdown
      @mutex.synchronize do
        return if shutdown?
        @actor.on_shutdown
        @stop_event.set
      end
    end

    def join(limit = nil)
      @stop_event.wait(limit)
    end

    private

    Message = Struct.new(:payload, :ivar, :callback)

    def set_stop_event
      @stop_event.set
    end

    def process_message(message)
      result = ex = nil

      begin
        result = @actor.receive(*message.payload)
      rescue @exception_class => ex
        @actor.on_error(Time.now, message.payload, ex)
        if @reset_on_error
          @mutex.synchronize{ @actor = @actor.class.new(*@args) }
        end
      ensure
        now = Time.now
        message.ivar.complete(ex.nil?, result, ex)

        begin
          message.callback.call(now, result, ex) if message.callback
        rescue @exception_class => ex
          # suppress
        end
      end
    end
  end
end

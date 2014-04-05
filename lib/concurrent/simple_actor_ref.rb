require 'thread'

require 'concurrent/actor_ref'
require 'concurrent/ivar'

module Concurrent

  class SimpleActorRef
    include ActorRef

    def initialize(actor)
      @actor = actor
      @mutex = Mutex.new
      @queue = Queue.new
      @thread = nil
      @stopped = false
    end

    def running?
      @mutex.synchronize{ @stopped == false }
    end

    def shutdown?
      @mutex.synchronize{ @stopped == true }
    end

    def post(*msg, &block)
      raise ArgumentError.new('message cannot be empty') if msg.empty?
      @mutex.synchronize do
        supervise unless @stopped == true
      end
      ivar = IVar.new
      @queue.push(Message.new(msg, ivar, block))
      ivar
    end

    def post!(seconds, *msg)
      raise Concurrent::TimeoutError if seconds == 0
      ivar = self.post(*msg)
      ivar.value(seconds)
      if ivar.incomplete?
        raise Concurrent::TimeoutError
      elsif ivar.reason
        raise ivar.reason
      end
      ivar.value
    end

    def shutdown
      @mutex.synchronize do
        @stopped = true
        if @thread && @thread.alive?
          @thread.kill 
          @actor.on_shutdown
        end
      end
    end

    private

    Message = Struct.new(:payload, :ivar, :callback)

    def supervise
      if @thread.nil?
        @actor.on_start
        @thread = new_worker_thread
      elsif ! @thread.alive?
        @actor.on_restart
        @thread = new_worker_thread
      end
    end

    def new_worker_thread
      Thread.new do
        Thread.current.abort_on_exception = true
        run_message_loop
      end
    end

    def run_message_loop
      loop do
        message = @queue.pop
        result = ex = nil

        begin
          result = @actor.receive(*message.payload)
        rescue => ex
          # suppress
        ensure
          message.ivar.complete(ex.nil?, result, ex)
          message.callback.call(Time.now, result, ex) if message.callback
        end
      end
    end
  end
end

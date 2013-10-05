#require 'observer'
require 'thread'
require 'functional'

require 'concurrent/supervisor'

module Concurrent
  include PatternMatching

  class Channel
    behavior(:runnable)

    def initialize(&block)
      @mailbox = Queue.new
      @task = block
      @running = false
      @thread = nil
    end

    def send(*message)
      @mailbox.push(message)
    end

    def run
      return if running?
      listen
    end

    def stop
      return unless running?
      @mailbox.clear
      @mailbox.push(:stop)
    end

    def running?
      @running && ( @thread.nil? || @thread.alive? )
    end

    def run!
      return if running?
      @thread.kill unless @thread.nil?
      @thread = Thread.new do
        Thread.current.abort_on_exception = false
        listen
      end

      return @thread.alive?
    end

    protected

    def receive(*message)
      @task.call(*msg) unless @task.nil?
    end

    def listen
      loop do
        @running = true
        message = @mailbox.pop
        break if message == :stop
        begin
          receive(*message)
        rescue => ex
          # ???
        end
      end
      @running = false
    end
  end
end

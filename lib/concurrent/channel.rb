require 'concurrent/channel/runtime'

module Concurrent

  # {include:file:doc/channel.md}
  class Channel
    class Closed < StandardError; end

    def initialize(size = nil)
      @q = size ? SizedQueue.new(size) : Queue.new
      @closed = false
      @mutex = Mutex.new
      @waiting = []
    end

    private def lock!(&block)
      @mutex.synchronize(&block)
    end

    private def wait!
      @waiting << Thread.current
      @mutex.sleep
    end

    private def next!
      loop do
        thr = @waiting.shift
        break if thr.nil?
        next unless thr.alive?
        break thr.wakeup
      end
    end

    private def all!
      @waiting.dup.each { next! }
    end

    def recv
      lock! do
        loop do
          closed! if closed? && @q.empty?
          wait! && next if @q.empty?
          break @q.pop
        end
      end
    end
    alias_method :pop, :recv

    def send(val)
      lock! do
        fail Closed if closed?
        @q << val
        next!
      end
    end
    alias_method :push, :send
    alias_method :<<, :push

    def close
      lock! do
        return if closed?
        @closed = true
        all!
      end
    end

    def closed?
      @closed
    end

    private def closed!
      fail Closed
    end

    def each
      return enum_for(:each) unless block_given?

      loop do
        begin
          e = recv
        rescue Channel::Closed
          return
        else
          yield e
        end
      end
    end

    def receive_only!
      ReceiveOnly.new(self)
    end
    alias_method :r!, :receive_only!

    def send_only!
      SendOnly.new(self)
    end
    alias_method :s!, :send_only!

    class << self
      def select(*channels)
        selector = new
        threads = channels.map do |c|
          Thread.new { selector << [c.recv, c] }
        end
        yield selector.recv
      ensure
        selector.close
        threads.each(&:kill).each(&:join)
      end
    end

    class Direction < StandardError; end
    class Conversion < StandardError; end

    class ReceiveOnly
      def initialize(channel)
        @channel = channel
      end

      def recv
        @channel.recv
      end
      alias_method :pop, :recv

      def send(_)
        fail Direction, 'receive only'
      end
      alias_method :push, :send
      alias_method :<<, :push

      def close
        @channel.close
      end

      def closed?
        @channel.closed?
      end

      def receive_only!
        self
      end
      alias_method :r!, :receive_only!

      def send_only!
        fail Conversion, 'receive only'
      end
      alias_method :s!, :send_only!

      def hash
        @channel.hash
      end
    end

    class SendOnly
      def initialize(channel)
        @channel = channel
      end

      def recv
        fail Direction, 'send only'
      end
      alias_method :pop, :recv

      def send(val)
        @channel.send(val)
      end
      alias_method :push, :send
      alias_method :<<, :push

      def close
        @channel.close
      end

      def closed?
        @channel.closed?
      end

      def receive_only!
        fail Conversion, 'send only'
      end
      alias_method :r!, :receive_only!

      def send_only!
        self
      end
      alias_method :s!, :send_only!

      def hash
        @channel.hash
      end
    end
  end
end

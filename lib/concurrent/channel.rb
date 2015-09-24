require 'concurrent/channel/buffer'
require 'concurrent/channel/selector'

require 'concurrent/maybe'
require 'concurrent/executor/cached_thread_pool'

module Concurrent

  # {include:file:doc/channel.md}
  class Channel
    include Enumerable

    GOROUTINES = Concurrent::CachedThreadPool.new
    private_constant :GOROUTINES

    BUFFER_TYPES = {
      unbuffered: Buffer::Unbuffered,
      buffered: Buffer::Buffered,
      dropping: Buffer::Dropping,
      sliding: Buffer::Sliding
    }.freeze
    private_constant :BUFFER_TYPES

    DEFAULT_VALIDATOR = ->(value){ true }
    private_constant :DEFAULT_VALIDATOR

    Error = Class.new(StandardError)

    class ValidationError < Error
      def initialize(message = nil)
        message ||= 'invalid value'
      end
    end

    def initialize(opts = {})
      # undocumented -- for internal use only
      if opts.is_a? Buffer::Base
        @buffer = opts
        return
      end

      size = opts[:size]
      buffer = opts[:buffer]

      if size && buffer == :unbuffered
        raise ArgumentError.new('unbuffered channels cannot have a size')
      elsif size.nil? && buffer.nil?
        @buffer = BUFFER_TYPES[:unbuffered].new
      elsif size == 0 && buffer == :buffered
        @buffer = BUFFER_TYPES[:unbuffered].new
      elsif buffer == :unbuffered
        @buffer = BUFFER_TYPES[:unbuffered].new
      elsif size.nil? || size < 1
        raise ArgumentError.new('size must be at least 1 for this buffer type')
      else
        buffer ||= :buffered
        @buffer = BUFFER_TYPES[buffer].new(size)
      end

      @validator = opts.fetch(:validator, DEFAULT_VALIDATOR)
    end

    def size
      @buffer.size
    end
    alias_method :capacity, :size

    def put(item)
      return false unless validate(item, false, false)
      do_put(item)
    end
    alias_method :send, :put
    alias_method :<<, :put

    def put!(item)
      validate(item, false, true)
      ok = do_put(item)
      raise Error if !ok
      ok
    end

    def put?(item)
      if !validate(item, true, false)
        Concurrent::Maybe.nothing('invalid value')
      elsif do_put(item)
        Concurrent::Maybe.just(true)
      else
        Concurrent::Maybe.nothing
      end
    end

    def offer(item)
      return false unless validate(item, false, false)
      do_offer(item)
    end

    def offer!(item)
      validate(item, false, true)
      ok = do_offer(item)
      raise Error if !ok
      ok
    end

    def offer?(item)
      if !validate(item, true, false)
        Concurrent::Maybe.nothing('invalid value')
      elsif do_offer(item)
        Concurrent::Maybe.just(true)
      else
        Concurrent::Maybe.nothing
      end
    end

    def take
      item, _ = self.next
      item
    end
    alias_method :receive, :take
    alias_method :~, :take

    def take!
      item, _ = do_next
      raise Error if item == Buffer::NO_VALUE
      item
    end

    def take?
      item, _ = self.next?
      item
    end

    #
    #   @example
    #
    #     jobs = Channel.new
    #
    #     Channel.go do
    #       loop do
    #         j, more = jobs.next
    #         if more
    #           print "received job #{j}\n"
    #         else
    #           print "received all jobs\n"
    #           break
    #         end
    #       end
    #     end
    def next
      item, more = do_next
      item = nil if item == Buffer::NO_VALUE
      return item, more
    end

    def next?
      item, more = do_next
      item = if item == Buffer::NO_VALUE
               Concurrent::Maybe.nothing
             else
               Concurrent::Maybe.just(item)
             end
      return item, more
    end

    def poll
      (item = do_poll) == Buffer::NO_VALUE ? nil : item
    end

    def poll!
      item = do_poll
      raise Error if item == Buffer::NO_VALUE
      item
    end

    def poll?
      if (item = do_poll) == Buffer::NO_VALUE
        Concurrent::Maybe.nothing
      else
        Concurrent::Maybe.just(item)
      end
    end

    def each
      raise ArgumentError.new('no block given') unless block_given?
      loop do
        item, more = do_next
        if item != Buffer::NO_VALUE
          yield(item)
        elsif !more
          break
        end
      end
    end

    def close
      @buffer.close
    end
    alias_method :stop, :close

    class << self
      def timer(seconds)
        Channel.new(Buffer::Timer.new(seconds))
      end
      alias_method :after, :timer

      def ticker(interval)
        Channel.new(Buffer::Ticker.new(interval))
      end
      alias_method :tick, :ticker

      def select(*args)
        raise ArgumentError.new('no block given') unless block_given?
        selector = Selector.new
        yield(selector, *args)
        selector.execute
      end
      alias_method :alt, :select

      def go(*args, &block)
        go_via(GOROUTINES, *args, &block)
      end

      def go_via(executor, *args, &block)
        raise ArgumentError.new('no block given') unless block_given?
        executor.post(*args, &block)
      end

      def go_loop(*args, &block)
        go_loop_via(GOROUTINES, *args, &block)
      end

      def go_loop_via(executor, *args, &block)
        raise ArgumentError.new('no block given') unless block_given?
        executor.post(block, *args) do
          loop do
            break unless block.call(*args)
          end
        end
      end
    end

    private

    def validate(value, allow_nil, raise_error)
      if !allow_nil && value.nil?
        raise_error ? raise(ValidationError.new('nil is not a valid value')) : false
      elsif !@validator.call(value)
        raise_error ? raise(ValidationError) : false
      else
        true
      end
    rescue => ex
      # the validator raised an exception
      return raise_error ? raise(ex) : false
    end

    def do_put(item)
      @buffer.put(item)
    end

    def do_offer(item)
      @buffer.offer(item)
    end

    def do_next
      @buffer.next
    end

    def do_poll
      @buffer.poll
    end
  end
end

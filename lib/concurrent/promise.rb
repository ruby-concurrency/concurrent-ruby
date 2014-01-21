require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'

module Concurrent

  class Promise
    include Obligation
    include UsesGlobalThreadPool

    # Creates a new promise object. "A promise represents the eventual
    # value returned from the single completion of an operation."
    # Promises can be chained in a tree structure where each promise
    # has zero or more children. Promises are resolved asynchronously
    # in the order they are added to the tree. Parents are guaranteed
    # to be resolved before their children. The result of each promise
    # is passed to each of its children upon resolution. When
    # a promise is rejected all its children will be summarily rejected.
    # A promise that is neither resolved or rejected is pending.
    #
    # @param args [Array] zero or more arguments for the block
    # @param block [Proc] the block to call when attempting fulfillment
    #
    # @see http://wiki.commonjs.org/wiki/Promises/A
    # @see http://promises-aplus.github.io/promises-spec/
    def initialize(*args, &block)
      if args.first.is_a?(Promise)
        @parent = args.first
      else
        @parent = nil
        @chain = [self]
      end

      @lock = Mutex.new
      @handler = block || Proc.new{|result| result }
      @state = :pending
      @value = nil
      @reason = nil
      @rescued = false
      @children = []
      @rescuers = []

      init_mutex
      realize(*args) if root?
    end

    def rescued?
      return @rescued
    end

    # Create a new child Promise. The block argument for the child will
    # be the result of fulfilling its parent. If the child will
    # immediately be rejected if the parent has already been rejected.
    #
    # @param block [Proc] the block to call when attempting fulfillment
    #
    # @return [Promise] the new promise
    def then(&block)
      child = @lock.synchronize do
        block = Proc.new{|result| result } if block.nil?
        @children << Promise.new(self, &block)
        @children.last.on_reject(@reason) if rejected?
        push(@children.last)
        @children.last
      end
      return child
    end

    # Add a rescue handler to be run if the promise is rejected (via raised
    # exception). Multiple rescue handlers may be added to a Promise.
    # Rescue blocks will be checked in order and the first one with a
    # matching Exception class will be processed. The block argument
    # will be the exception that caused the rejection.
    #
    # @param clazz [Class] The class of exception to rescue
    # @param block [Proc] the block to call if the rescue is matched
    #
    # @return [self] so that additional chaining can occur
    def rescue(clazz = nil, &block)
      return self if fulfilled? || rescued? || block.nil?
      @lock.synchronize do
        rescuer = Rescuer.new(clazz, block)
        if pending?
          @rescuers << rescuer
        else
          try_rescue(reason, rescuer)
        end
      end
      return self
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    protected

    attr_reader :parent
    attr_reader :handler
    attr_reader :rescuers

    # @private
    Rescuer = Struct.new(:clazz, :block)

    # @private
    def root? # :nodoc:
      @parent.nil?
    end

    # @private
    def push(promise) # :nodoc:
      if root?
        @chain << promise
      else
        @parent.push(promise)
      end
    end

    # @private
    def on_fulfill(result) # :nodoc:
      @lock.synchronize do
        @value = @handler.call(result)
        @state = :fulfilled
        @reason = nil
      end
      return self.value
    end

    # @private
    def on_reject(reason) # :nodoc:
      @value = nil
      @state = :rejected
      @reason = reason
      try_rescue(reason)
      @children.each{|child| child.on_reject(reason) }
    end

    # @private
    def try_rescue(ex, *rescuers) # :nodoc:
      rescuers = @rescuers if rescuers.empty?
      rescuer = rescuers.find{|r| r.clazz.nil? || ex.is_a?(r.clazz) }
      if rescuer
        rescuer.block.call(ex)
        @rescued = true
      end
    rescue Exception => ex
      # supress
    end

    # @private
    def realize(*args) # :nodoc:
      Promise.thread_pool.post(@chain, @lock, args) do |chain, lock, args|
        result = args.length == 1 ? args.first : args
        index = 0
        loop do
          current = lock.synchronize{ chain[index] }
          unless current.rejected?
            begin
              result = current.on_fulfill(result)
            rescue Exception => ex
              current.on_reject(ex)
            ensure
              event.set
            end
          end
          index += 1
          Thread.pass while index >= chain.length
        end
      end
    end
  end
end

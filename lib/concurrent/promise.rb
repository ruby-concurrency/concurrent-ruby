require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/utilities'

module Concurrent

  class Promise
    include Obligation
    include UsesGlobalThreadPool

    behavior(:future)
    behavior(:promise)

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
      @children = []
      @rescuers = []

      realize(*args) if root?
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
        block = Proc.new{|result| result } unless block_given?
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
    def rescue(clazz = Exception, &block)
      @lock.synchronize do
        @rescuers << Rescuer.new(clazz, block) if block_given?
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
    def on_fulfill(value) # :nodoc:
      @lock.synchronize do
        if pending?
          @value = @handler.call(value)
          @state = :fulfilled
          @reason = nil
        end
      end
      return @value
    end

    # @private
    def on_reject(reason) # :nodoc:
      @lock.synchronize do
        if pending?
          @state = :rejected
          @reason = reason
          self.try_rescue(reason)
          @value = nil
        end
        @children.each{|child| child.on_reject(reason) }
      end
    end

    # @private
    def try_rescue(ex) # :nodoc:
      rescuer = @rescuers.find{|r| ex.is_a?(r.clazz) }
      rescuer.block.call(ex) if rescuer
    rescue Exception => e
      # supress
    end

    # @private
    def realize(*args) # :nodoc:
      Promise.thread_pool.post(@chain, @lock, args) do |chain, lock, args|
        result = args.length == 1 ? args.first : args
        index = 0
        loop do
          Thread.pass
          current = lock.synchronize{ chain[index] }
          unless current.rejected?
            current.mutex.synchronize do
              begin
                result = current.on_fulfill(result)
              rescue Exception => ex
                current.on_reject(ex)
              end
            end
          end
          index += 1
          sleep while index >= chain.length
        end
      end
    end
  end
end

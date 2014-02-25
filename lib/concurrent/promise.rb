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
      @state = :unscheduled
      @rescued = false
      @children = []
      @args = args

      init_obligation
    end

    def self.fulfil(value)
      Promise.new.tap { |p| p.send(:set_state!, true, value, nil) }
    end

    def self.reject(reason)
      Promise.new.tap { |p| p.send(:set_state!, false, nil, reason) }
    end

    # @return [Promise]
    def execute
      if root?
        if compare_and_set_state(:pending, :unscheduled)
          set_pending
          realize(*@args)
        end
      else
        parent.execute
      end
      self
    end

    def self.execute(*args, &block)
      new(*args, &block).execute
    end

    def rescued?
      return @rescued
    end


    # @return [Promise] the new promise
    def then(rescuer = nil, &block)
      raise ArgumentError.new('rescuers and block are both missing') if rescuer.nil? && !block_given?
      block = Proc.new{ |result| result } if block.nil?
      child = Promise.new(self, &block)

      @lock.synchronize do
        child.state = :pending if @state == :pending
        @children << child
        child.on_reject(@reason) if rejected?
        push(child)
      end

      child
    end

    # @return [Promise]
    def on_success(&block)
      raise ArgumentError.new('no block given') unless block_given?
      self.then &block
    end


    # @return [Promise]
    def rescue(rescuer)
      self.then(rescuer)
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    protected

    attr_reader :parent
    attr_reader :handler
    attr_reader :rescuers

    def set_pending
      self.state = :pending
      @children.each { |c| c.set_pending }
    end

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
      success, value, reason = SafeTaskExecutor.new(Proc.new{ @handler.call(result) }).execute
      set_state!(success, value, reason)
      @children.each{ |child| child.on_fulfill(self.value) }
      return self.value
    end

    # @private
    def on_reject(reason) # :nodoc:
      @value = nil
      @state = :rejected
      @reason = reason
      try_rescue(reason)
      @children.each{ |child| child.on_reject(reason) }
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

    def set_state!(success, value, reason)
      mutex.synchronize do
        set_state(success, value, reason)
        event.set
      end
    end

  end
end

require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'

module Concurrent

  class Promise
    include Obligation
    include UsesGlobalThreadPool

    # @see http://wiki.commonjs.org/wiki/Promises/A
    # @see http://promises-aplus.github.io/promises-spec/
    def initialize(options = {}, &block)
      options.delete_if {|k, v| v.nil?}

      @parent = options.fetch(:parent) { nil }
      @on_fulfill = options.fetch(:on_fulfill) { Proc.new{ |result| result } }
      @on_reject = options.fetch(:on_reject) { Proc.new{ |reason| raise reason } }

      @promise_body = block || Proc.new{|result| result }
      @state = :unscheduled
      @children = []

      init_obligation
    end

    # @return [Promise]
    def self.fulfill(value)
      Promise.new.tap { |p| p.send(:synchronized_set_state!, true, value, nil) }
    end


    # @return [Promise]
    def self.reject(reason)
      Promise.new.tap { |p| p.send(:synchronized_set_state!, false, nil, reason) }
    end

    # @return [Promise]
    # @since 0.5.0
    def execute
      if root?
        if compare_and_set_state(:pending, :unscheduled)
          set_pending
          realize(@promise_body)
        end
      else
        @parent.execute
      end
      self
    end

    # @since 0.5.0
    def self.execute(&block)
      new(&block).execute
    end


    # @return [Promise] the new promise
    def then(rescuer = nil, &block)
      raise ArgumentError.new('rescuers and block are both missing') if rescuer.nil? && !block_given?
      block = Proc.new{ |result| result } if block.nil?
      child = Promise.new(parent: self, on_fulfill: block, on_reject: rescuer)

      mutex.synchronize do
        child.state = :pending if @state == :pending
        child.on_fulfill(apply_deref_options(@value)) if @state == :fulfilled
        child.on_reject(@reason) if @state == :rejected
        @children << child
      end

      child
    end

    # @return [Promise]
    def on_success(&block)
      raise ArgumentError.new('no block given') unless block_given?
      self.then &block
    end

    # @return [Promise]
    def rescue(&block)
      self.then(block)
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    protected

    def set_pending
      mutex.synchronize do
        @state = :pending
        @children.each { |c| c.set_pending }
      end
    end

    # @!visibility private
    def root? # :nodoc:
      @parent.nil?
    end

    # @!visibility private
    def on_fulfill(result)
      realize Proc.new{ @on_fulfill.call(result) }
      nil
    end

    # @!visibility private
    def on_reject(reason)
      realize Proc.new{ @on_reject.call(reason) }
      nil
    end

    def notify_child(child)
      if_state(:fulfilled) { child.on_fulfill(apply_deref_options(@value)) }
      if_state(:rejected) { child.on_reject(@reason) }
    end

    # @!visibility private
    def realize(task)
      Promise.thread_pool.post do
        success, value, reason = SafeTaskExecutor.new( task ).execute

        children_to_notify = mutex.synchronize do
          set_state!(success, value, reason)
          @children.dup
        end

        children_to_notify.each{ |child| notify_child(child) }
      end
    end

    def set_state!(success, value, reason)
      set_state(success, value, reason)
      event.set
    end

    def synchronized_set_state!(success, value, reason)
      mutex.synchronize do
        set_state!(success, value, reason)
      end
    end

  end
end

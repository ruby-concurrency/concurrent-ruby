require 'thread'

require 'concurrent/global_thread_pool'

module Concurrent

  IllegalMethodCallError = Class.new(StandardError)

  class Defer
    include UsesGlobalThreadPool

    def initialize(opts = {}, &block)
      operation = opts[:op] || opts[:operation]
      @callback = opts[:cback] || opts[:callback]
      @errorback = opts[:eback] || opts[:error] || opts[:errorback]
      thread_pool = opts[:pool] || opts[:thread_pool]

      raise ArgumentError.new('no operation given') if operation.nil? && ! block_given?
      raise ArgumentError.new('two operations given') if ! operation.nil? && block_given?

      @operation = operation || block

      if operation.nil?
        @running = false
      else
        self.go
      end
    end

    def then(&block)
      raise IllegalMethodCallError.new('a callback has already been provided') unless @callback.nil?
      raise IllegalMethodCallError.new('the defer is already running') if @running
      raise ArgumentError.new('no block given') unless block_given?
      @callback = block
      return self
    end

    def rescue(&block)
      raise IllegalMethodCallError.new('a errorback has already been provided') unless @errorback.nil?
      raise IllegalMethodCallError.new('the defer is already running') if @running
      raise ArgumentError.new('no block given') unless block_given?
      @errorback = block
      return self
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    def go
      return nil if @running
      atomic {
        @running = true
        Defer.thread_pool.post { Thread.pass; fulfill }
      }
      return nil
    end

    private

    # @private
    def fulfill # :nodoc:
      result = @operation.call
      @callback.call(result) unless @callback.nil?
    rescue Exception => ex
      @errorback.call(ex) unless @errorback.nil?
    end
  end
end

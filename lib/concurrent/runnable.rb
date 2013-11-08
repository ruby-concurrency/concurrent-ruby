require 'thread'

module Concurrent

  module Runnable

    LifecycleError = Class.new(StandardError)

    class Context
      attr_reader :runner, :thread
      def initialize(runner)
        @runner = runner
        @thread = Thread.new(runner) do |runner|
          Thread.abort_on_exception = false
          runner.run
        end
        @thread.join(0.1) # let the thread start
      end
    end

    def self.included(base)

      class << base

        def run!(*args, &block)
          runner = self.new(*args, &block)
          return Context.new(runner)
        rescue => ex
          return nil
        end
      end
    end

    def run!(abort_on_exception = false)
      raise LifecycleError.new('already running') if @running
      thread = Thread.new do
        Thread.current.abort_on_exception = abort_on_exception
        self.run
      end
      thread.join(0.1) # let the thread start
      return thread
    end

    def run
      mutex.synchronize do
        raise LifecycleError.new('already running') if @running
        raise LifecycleError.new('#on_task not implemented') unless self.respond_to?(:on_task, true)
        on_run if respond_to?(:on_run, true)
        @running = true
      end

      loop do
        break unless @running
        on_task
        break unless @running
        Thread.pass
      end

      after_run if respond_to?(:after_run, true)
      return true
    rescue LifecycleError => ex
      @running = false
      raise ex
    rescue => ex
      @running = false
      return false
    end

    def stop
      return true unless @running
      mutex.synchronize do
        @running = false
        on_stop if respond_to?(:on_stop, true)
      end
      return true
    rescue => ex
      return false
    end

    def running?
      return @running == true
    end

    protected

    def mutex
      @mutex ||= Mutex.new
    end
  end
end

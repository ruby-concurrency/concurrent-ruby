require 'thread'
require 'observer'

require 'concurrent/runnable'
require 'concurrent/utilities'

module Concurrent

  class TimerTask
    include Runnable
    include Observable

    EXECUTION_INTERVAL = 60
    TIMEOUT_INTERVAL = 30

    attr_reader :execution_interval
    attr_reader :timeout_interval

    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      @execution_interval = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      @timeout_interval = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL
      @run_now = opts[:now] || opts[:run_now] || false
      @block_args = opts[:args] || opts [:arguments] || []

      @task = block
    end

    def kill
      return true unless running?
      mutex.synchronize do
        @running = false
        Thread.kill(@worker) unless @worker.nil?
        Thread.kill(@monitor) unless @monitor.nil?
      end
      return true
    rescue
      return false
    ensure
      @worker = @monitor = nil
    end
    alias_method :terminate, :kill

    alias_method :cancel, :stop

    protected

    def on_run
      @monitor = Thread.current
    end

    def on_stop
      @monitor.wakeup if @monitor.alive?
      Thread.pass
    end

    def on_task
      if @run_now
        @run_now = false
      else
        sleep(@execution_interval)
      end
      execute_task
    end

    def execute_task
      @worker = Thread.new do
        Thread.current.abort_on_exception = false
        Thread.current[:result] = @task.call(*@block_args)
      end
      raise TimeoutError if @worker.join(@timeout_interval).nil?
      changed
      notify_observers(Time.now, @worker[:result], nil)
    rescue Exception => ex
      changed
      notify_observers(Time.now, nil, ex)
    ensure
      unless @worker.nil?
        Thread.kill(@worker)
        @worker = nil
      end
    end
  end
end

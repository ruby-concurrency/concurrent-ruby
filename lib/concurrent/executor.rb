require 'thread'
require 'concurrent/runnable'

module Concurrent

  class Executor
    include Runnable
    behavior(:runnable)

    EXECUTION_INTERVAL = 60
    TIMEOUT_INTERVAL = 30

    STDOUT_LOGGER = proc do |name, level, msg|
      print "%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg]
    end

    attr_reader :name
    attr_reader :execution_interval
    attr_reader :timeout_interval

    def initialize(name, opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      @name = name
      @execution_interval = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      @timeout_interval = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL
      @run_now = opts[:now] || opts[:run_now] || false
      @logger = opts[:logger] || STDOUT_LOGGER
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

    def status
      return @monitor.status unless @monitor.nil?
    end

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
        @task.call(*@block_args)
      end
      if @worker.join(@timeout_interval).nil?
        @logger.call(@name, :warn, "execution timed out after #{@timeout_interval} seconds")
      else
        @logger.call(@name, :info, 'execution completed successfully')
      end
    rescue Exception => ex
      @logger.call(@name, :error, "execution failed with error '#{ex}'")
    ensure
      unless @worker.nil?
        Thread.kill(@worker)
        @worker = nil
      end
    end
  end
end

require 'thread'
require 'concurrent/supervisor'

module Concurrent

  class Executor

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
      @running = false
      @mutex = Mutex.new
    end

    def run!
      return true if running?
      @thread = Thread.new do
        Thread.current.abort_on_exception = false
        monitor
      end
      Thread.pass
      return running?
    end

    def run
      monitor unless running?
    end

    def stop
      return true if @thread.nil?
      @running = false
      Thread.pass
      return ! running?
    end

    def kill
      Thread.kill(@worker) unless @worker.nil?

      case @thread.status
      when 'sleep'
        Thread.kill(@thread)
      when 'run'
        Thread.kill(@thread) if @thread.join(1).nil?
      end

      return true
    rescue => ex
      return false
    ensure
      @thread = nil
    end
    alias_method :terminate, :kill

    def running?
      return @running && @thread && @thread.alive?
    end

    def status
      return @thread.status unless @thread.nil?
    end

    def join(limit = nil)
      if @thread.nil?
        return nil
      elsif limit.nil?
        return @thread.join
      else
        return @thread.join(limit)
      end
    end

    def self.run(name, opts = {}, &block)
      executor = Executor.new(name, opts, &block)
      executor.run!
      return executor
    end

    private

    def monitor
      @running = true
      @thread = Thread.current if @thread.nil?

      sleep(@execution_interval) unless @run_now == true

      loop do
        break unless @running
        begin
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
        break unless @running
        sleep(@execution_interval)
      end
      @thread = nil
    end
  end

  # backward compatibility
  Executor::ExecutionContext = Executor
end

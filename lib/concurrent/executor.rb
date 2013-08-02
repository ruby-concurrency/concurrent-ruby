require 'thread'

module Concurrent

  ExecutionContext = Struct.new(
    :name,
    :execution_interval,
    :timeout_interval,
    :thread
  )

  module Executor
    extend self

    EXECUTION_INTERVAL = 60
    TIMEOUT_INTERVAL = 30

    STDOUT_LOGGER = proc do |name, level, msg|
      print "%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg]
    end

    def run(name, opts = {})
      raise ArgumentError.new('no block given') unless block_given?

      execution_interval = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      timeout_interval = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL
      logger = opts[:logger] || STDOUT_LOGGER
      block_args = opts[:args] || opts [:arguments] || []

      executor = Thread.new(*block_args) do |*args|
        loop do
          sleep(execution_interval)
          begin
            worker = Thread.new{ yield(*args) }
            worker.abort_on_exception = false
            if worker.join(timeout_interval).nil?
              logger.call(name, :warn, "execution timed out after #{timeout_interval} seconds")
            else
              logger.call(name, :info, 'execution completed successfully')
            end
          rescue Exception => ex
            logger.call(name, :error, "execution failed with error '#{ex}'")
          ensure
            Thread.kill(worker)
            worker = nil
          end
        end
      end

      return ExecutionContext.new(name, execution_interval, timeout_interval, executor)
    end
  end
end

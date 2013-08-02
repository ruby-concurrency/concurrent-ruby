require 'thread'

module Concurrent

  module Executor
    extend self

    EXECUTION_INTERVAL = 60
    TIMEOUT_INTERVAL = 30

    STDOUT_LOGGER = proc do |name, level, msg|
      print "%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg]
    end

    def run(name, opts = {})
      return ArgumentError.new('no block given') unless block_given?

      execution = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      timeout = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL
      logger = opts[:logger] || STDOUT_LOGGER

      executor = Thread.new do
        loop do
          sleep(execution)
          begin
            worker = Thread.new{ yield }
            worker.abort_on_exception = false
            if worker.join(timeout).nil?
              logger.call(name, :warn, "execution timed out after #{timeout} seconds")
              Thread.kill(worker)
            else
              logger.call(name, :info, 'execution completed successfully')
            end
          rescue Exception => ex
            logger.call(name, :error, "execution failed with error '#{ex}'")
          ensure
            worker = nil
          end
        end
      end

      return executor
    end
  end
end

module Kernel

  def executor(*args, &block)
    return Concurrent::Executor.run(*args, &block)
  end
  module_function :executor
end

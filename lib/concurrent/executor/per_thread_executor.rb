require 'concurrent/atomics'
require 'concurrent/executor/executor'

module Concurrent

  # An executor service in which every operation spawns a new,
  # independently operating thread.
  class PerThreadExecutor
    include SerialExecutor

    # Creates a new executor
    def initialize
      @running = Concurrent::AtomicBoolean.new(true)
      @stopped = Concurrent::Event.new
      @count = Concurrent::AtomicFixnum.new(0)
    end

    # @!macro executor_method_post
    def self.post(*args)
      raise ArgumentError.new('no block given') unless block_given?
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        yield(*args)
      end
      true
    end

    # @!macro executor_method_left_shift
    def self.<<(task)
      post(&task)
      self
    end

    # @!macro executor_method_post
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      return false unless running?
      @count.increment
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        begin
          yield(*args)
        ensure
          @count.decrement
          @stopped.set if @running.false? && @count.value == 0
        end
      end
    end

    # @!macro executor_method_left_shift
    def <<(task)
      post(&task)
      self
    end

    # @!macro executor_method_running_question
    def running?
      @running.true?
    end

    # @!macro executor_method_shuttingdown_question
    def shuttingdown?
      @running.false? && ! @stopped.set?
    end

    # @!macro executor_method_shutdown_question
    def shutdown?
      @stopped.set?
    end

    # @!macro executor_method_shutdown
    def shutdown
      @running.make_false
      @stopped.set if @count.value == 0
      true
    end

    # @!macro executor_method_kill
    def kill
      @running.make_false
      @stopped.set
      true
    end

    # @!macro executor_method_wait_for_termination
    def wait_for_termination(timeout = nil)
      @stopped.wait(timeout)
    end
  end
end

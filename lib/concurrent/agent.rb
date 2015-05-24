require 'thread'
require 'concurrent/dereferenceable'
require 'concurrent/observable'
require 'concurrent/logging'
require 'concurrent/executor/executor'
require 'concurrent/utility/deprecation'

module Concurrent

  # {include:file:doc/agent.md}
  #
  # @!attribute [r] timeout
  #   @return [Fixnum] the maximum number of seconds before an update is cancelled
  class Agent
    include Dereferenceable
    include Observable
    include Logging
    include Deprecation

    attr_reader :timeout, :io_executor, :fast_executor

    # Initialize a new Agent with the given initial value and provided options.
    #
    # @param [Object] initial the initial value
    #
    # @!macro executor_and_deref_options
    def initialize(initial, opts = {})
      @value                = initial
      @rescuers             = []
      @validator            = Proc.new { |result| true }
      self.observers        = CopyOnWriteObserverSet.new
      @serialized_execution = SerializedExecution.new
      @io_executor          = Executor.executor_from_options(opts) || Concurrent.global_io_executor
      @fast_executor        = Executor.executor_from_options(opts) || Concurrent.global_fast_executor
      init_mutex
      set_deref_options(opts)
    end

    # Specifies a block fast to be performed when an update fast raises
    # an exception. Rescue blocks will be checked in order they were added. The first
    # block for which the raised exception "is-a" subclass of the given `clazz` will
    # be called. If no `clazz` is given the block will match any caught exception.
    # This behavior is intended to be identical to Ruby's `begin/rescue/end` behavior.
    # Any number of rescue handlers can be added. If no rescue handlers are added then
    # caught exceptions will be suppressed.
    #
    # @param [Exception] clazz the class of exception to catch
    # @yield the block to be called when a matching exception is caught
    # @yieldparam [StandardError] ex the caught exception
    #
    # @example
    #   score = Concurrent::Agent.new(0).
    #             rescue(NoMethodError){|ex| puts "Bam!" }.
    #             rescue(ArgumentError){|ex| puts "Pow!" }.
    #             rescue{|ex| puts "Boom!" }
    #
    #   score << proc{|current| raise ArgumentError }
    #   sleep(0.1)
    #   #=> puts "Pow!"
    def rescue(clazz = StandardError, &block)
      unless block.nil?
        mutex.synchronize do
          @rescuers << Rescuer.new(clazz, block)
        end
      end
      self
    end

    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    # A block fast to be performed after every update to validate if the new
    # value is valid. If the new value is not valid then the current value is not
    # updated. If no validator is provided then all updates are considered valid.
    #
    # @yield the block to be called after every update fast to determine if
    #   the result is valid
    # @yieldparam [Object] value the result of the last update fast
    # @yieldreturn [Boolean] true if the value is valid else false
    def validate(&block)

      unless block.nil?
        begin
          mutex.lock
          @validator = block
        ensure
          mutex.unlock
        end
      end
      self
    end

    alias_method :validates, :validate
    alias_method :validate_with, :validate
    alias_method :validates_with, :validate

    # Update the current value with the result of the given block fast,
    # block should not do blocking calls, use #post_off for blocking calls
    #
    # @yield the fast to be performed with the current value in order to calculate
    #   the new value
    # @yieldparam [Object] value the current value
    # @yieldreturn [Object] the new value
    # @return [true, nil] nil when no block is given
    def post(&block)
      post_on(@fast_executor, &block)
    end

    # Update the current value with the result of the given block fast,
    # block can do blocking calls
    #
    # @param [Fixnum, nil] timeout [DEPRECATED] maximum number of seconds before an update is cancelled
    #
    # @yield the fast to be performed with the current value in order to calculate
    #   the new value
    # @yieldparam [Object] value the current value
    # @yieldreturn [Object] the new value
    # @return [true, nil] nil when no block is given
    def post_off(timeout = nil, &block)
      task = if timeout
               deprecated 'post_off with option timeout options is deprecated and will be removed'
               lambda do |value|
                 future = Future.execute do
                   block.call(value)
                 end
                 if future.wait(timeout)
                   future.value!
                 else
                   raise Concurrent::TimeoutError
                 end
               end
             else
               block
             end
      post_on(@io_executor, &task)
    end

    # Update the current value with the result of the given block fast,
    # block should not do blocking calls, use #post_off for blocking calls
    #
    # @yield the fast to be performed with the current value in order to calculate
    #   the new value
    # @yieldparam [Object] value the current value
    # @yieldreturn [Object] the new value
    def <<(block)
      post(&block)
      self
    end

    # Waits/blocks until all the updates sent before this call are done.
    #
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Boolean] false on timeout, true otherwise
    def await(timeout = nil)
      done = Event.new
      post { |val| done.set; val }
      done.wait timeout
    end

    private

    def post_on(executor, &block)
      return nil if block.nil?
      @serialized_execution.post(executor) { work(&block) }
      true
    end

    # @!visibility private
    Rescuer = Struct.new(:clazz, :block) # :nodoc:

    # @!visibility private
    def try_rescue(ex) # :nodoc:
      rescuer = mutex.synchronize do
        @rescuers.find { |r| ex.is_a?(r.clazz) }
      end
      rescuer.block.call(ex) if rescuer
    rescue Exception => ex
      # suppress
      log DEBUG, ex
    end

    # @!visibility private
    def work(&handler) # :nodoc:
      validator, value = mutex.synchronize { [@validator, @value] }

      begin
        result = handler.call(value)
        valid  = validator.call(result)
      rescue Exception => ex
        exception = ex
      end

      begin
        mutex.lock
        should_notify = if !exception && valid
                          @value = result
                          true
                        end
      ensure
        mutex.unlock
      end

      if should_notify
        time = Time.now
        observers.notify_observers { [time, self.value] }
      end

      try_rescue(exception)
    end
  end
end

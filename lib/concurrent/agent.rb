require 'thread'
require 'observer'

require 'concurrent/dereferenceable'
require 'concurrent/global_thread_pool'
require 'concurrent/utilities'

module Concurrent

  # An agent is a single atomic value that represents an identity. The current value
  # of the agent can be requested at any time (#deref). Each agent has a work queue and operates on
  # the global thread pool. Consumers can #post code blocks to the agent. The code block (function)
  # will receive the current value of the agent as its sole parameter. The return value of the block
  # will become the new value of the agent. Agents support two error handling modes: fail and continue.
  # A good example of an agent is a shared incrementing counter, such as the score in a video game.
  #
  # @example Basic usage
  #   score = Concurrent::Agent.new(10)
  #   score.value #=> 10
  #   
  #   score << proc{|current| current + 100 }
  #   sleep(0.1)
  #   score.value #=> 110
  #   
  #   score << proc{|current| current * 2 }
  #   sleep(0.1)
  #   score.value #=> 220
  #   
  #   score << proc{|current| current - 50 }
  #   sleep(0.1)
  #   score.value #=> 170
  #
  # @!attribute [r] timeout
  #   @return [Fixnum] the maximum number of seconds before an update is cancelled
  #
  # @see http://ruby-doc.org/stdlib-2.1.1/libdoc/observer/rdoc/Observable.html Ruby +Observable+ module
  class Agent
    include Observable
    include Dereferenceable
    include UsesGlobalThreadPool

    # The default timeout value (in seconds); used when no timeout option
    # is given at initialization
    TIMEOUT = 5

    attr_reader :timeout

    # Initialize a new Agent with the given initial value and provided options.
    #
    # @param [Object] initial the initial value
    # @param [Hash] opts the options used to define the behavior at update and deref
    # @option opts [Fixnum] :timeout (TIMEOUT) maximum number of seconds before an update is cancelled
    # @option opts [String] :dup_on_deref (false) call +#dup+ before returning the data
    # @option opts [String] :freeze_on_deref (false) call +#freeze+ before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given +Proc+ passing the internal value and
    #   returning the value returned from the proc
    def initialize(initial, opts = {})
      @value = initial
      @rescuers = []
      @validator = nil
      @timeout = opts.fetch(:timeout, TIMEOUT).freeze
      init_mutex
      set_deref_options(opts)
    end

    # Specifies a block operation to be performed when an update operation raises
    # an exception. Rescue blocks will be checked in order they were added. The first
    # block for which the raised exception "is-a" subclass of the given +clazz+ will
    # be called. If no +clazz+ is given the block will match any caught exception.
    # This behavior is intended to be identical to Ruby's +begin/rescue/end+ behavior.
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
      return self
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    # A block operation to be performed after every update to validate if the new
    # value is valid. If the new value is not valid then the current value is not
    # updated. If no validator is provided then all updates are considered valid.
    #
    # @yield the block to be called after every update operation to determine if
    #   the result is valid
    # @yieldparam [Object] value the result of the last update operation
    # @yieldreturn [Boolean] true if the value is valid else false
    def validate(&block)
      @validator = block unless block.nil?
      return self
    end
    alias_method :validates, :validate
    alias_method :validate_with, :validate
    alias_method :validates_with, :validate

    # Update the current value with the result of the given block operation
    #
    # @yield the operation to be performed with the current value in order to calculate
    #   the new value
    # @yieldparam [Object] value the current value
    # @yieldreturn [Object] the new value
    def post(&block)
      Agent.thread_pool.post{ work(&block) } unless block.nil?
    end

    # Update the current value with the result of the given block operation
    #
    # @yield the operation to be performed with the current value in order to calculate
    #   the new value
    # @yieldparam [Object] value the current value
    # @yieldreturn [Object] the new value
    def <<(block)
      self.post(&block)
      return self
    end

    alias_method :add_watch, :add_observer

    private

    # @!visibility private
    Rescuer = Struct.new(:clazz, :block) # :nodoc:

    # @!visibility private
    def try_rescue(ex) # :nodoc:
      rescuer = mutex.synchronize do
        @rescuers.find{|r| ex.is_a?(r.clazz) }
      end
      rescuer.block.call(ex) if rescuer
    rescue Exception => ex
      # supress
    end

    # @!visibility private
    def work(&handler) # :nodoc:
      begin
        mutex.synchronize do
          result = Concurrent::timeout(@timeout) do
            handler.call(@value)
          end
          if @validator.nil? || @validator.call(result)
            @value = result
            changed
          end
        end
        notify_observers(Time.now, self.value) if self.changed?
      rescue Exception => ex
        try_rescue(ex)
      end
    end
  end
end

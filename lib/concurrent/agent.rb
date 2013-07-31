require 'observer'
require 'thread'

require 'concurrent/utilities'

module Concurrent

  # An agent is a single atomic value that represents an identity. The current value
  # of the agent can be requested at any time (#deref). Each agent has a work queue and operates on
  # the global thread pool. Consumers can #post code blocks to the agent. The code block (function)
  # will receive the current value of the agent as its sole parameter. The return value of the block
  # will become the new value of the agent. Agents support two error handling modes: fail and continue.
  # A good example of an agent is a shared incrementing counter, such as the score in a video game.
  class Agent
    include Observable

    TIMEOUT = 5

    attr_reader :initial
    attr_reader :timeout

    def initialize(initial, timeout = TIMEOUT)
      @value = initial
      @timeout = timeout
      @rescuers = []
      @validator = nil
      @queue = Queue.new

      @thread = Thread.new{ work }
    end

    def value(timeout = 0) return @value; end
    alias_method :deref, :value

    def rescue(clazz = Exception, &block)
      @rescuers << Rescuer.new(clazz, block) if block_given?
      return self
    end
    alias_method :catch, :rescue
    alias_method :on_error, :rescue

    def validate(&block)
      @validator = block if block_given?
      return self
    end
    alias_method :validates, :validate
    alias_method :validate_with, :validate
    alias_method :validates_with, :validate

    def post(&block)
      return @queue.length unless block_given?
      return atomic {
        @queue << block
        @queue.length
      }
    end

    def <<(block)
      self.post(&block)
      return self
    end

    def length
      @queue.length
    end
    alias_method :size, :length
    alias_method :count, :length

    alias_method :add_watch, :add_observer

    private

    # @private
    Rescuer = Struct.new(:clazz, :block)

    # @private
    def try_rescue(ex) # :nodoc:
      rescuer = @rescuers.find{|r| ex.is_a?(r.clazz) }
      rescuer.block.call(ex) if rescuer
    rescue Exception => e
      # supress
    end

    # @private
    def work # :nodoc:
      loop do
        Thread.pass
        handler = @queue.pop
        begin
          result = Timeout.timeout(@timeout){
            handler.call(@value)
          }
          if @validator.nil? || @validator.call(result)
            atomic {
              @value = result
              changed
            }
            notify_observers(Time.now, @value)
          end
        rescue Exception => ex
          try_rescue(ex)
        end
      end
    end
  end
end

module Kernel

  def agent(initial, timeout = Concurrent::Agent::TIMEOUT)
    return Concurrent::Agent.new(initial, timeout)
  end
  module_function :agent

  def deref(agent, timeout = nil)
    if agent.respond_to?(:deref)
      return agent.deref(timeout)
    elsif agent.respond_to?(:value)
      return agent.deref(timeout)
    else
      return nil
    end
  end
  module_function :deref

  def post(agent, &block)
    if agent.respond_to?(:post)
      return agent.post(&block)
    else
      return nil
    end
  end
  module_function :post
end

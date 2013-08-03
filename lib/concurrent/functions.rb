require 'concurrent/agent'
require 'concurrent/defer'
require 'concurrent/future'
require 'concurrent/promise'

module Kernel

  ## agent

  def agent(initial, timeout = Concurrent::Agent::TIMEOUT)
    return Concurrent::Agent.new(initial, timeout)
  end
  module_function :agent

  def post(agent, &block)
    if agent.respond_to?(:post)
      return agent.post(&block)
    else
      return nil
    end
  end
  module_function :post

  ## defer

  def defer(*args, &block)
    return Concurrent::Defer.new(*args, &block)
  end
  module_function :defer

  ## executor

  def executor(*args, &block)
    return Concurrent::Executor.run(*args, &block)
  end
  module_function :executor

  ## future

  def future(*args, &block)
    return Concurrent::Future.new(*args, &block)
  end
  module_function :future

  ## obligation

  def deref(obligation, timeout = nil)
    if obligation.respond_to?(:deref)
      return obligation.deref(timeout)
    elsif obligation.respond_to?(:value)
      return obligation.deref(timeout)
    else
      return nil
    end
  end
  module_function :deref

  def pending?(obligation)
    if obligation.respond_to?(:pending?)
      return obligation.pending?
    else
      return false
    end
  end
  module_function :pending?

  def fulfilled?(obligation)
    if obligation.respond_to?(:fulfilled?)
      return obligation.fulfilled?
    elsif obligation.respond_to?(:realized?)
      return obligation.realized?
    else
      return false
    end
  end
  module_function :fulfilled?

  def realized?(obligation)
    if obligation.respond_to?(:realized?)
      return obligation.realized?
    elsif obligation.respond_to?(:fulfilled?)
      return obligation.fulfilled?
    else
      return false
    end
  end
  module_function :realized?

  def rejected?(obligation)
    if obligation.respond_to?(:rejected?)
      return obligation.rejected?
    else
      return false
    end
  end
  module_function :rejected?

  ## promise

  # Creates a new promise object. "A promise represents the eventual
  # value returned from the single completion of an operation."
  # Promises can be chained in a tree structure where each promise
  # has zero or more children. Promises are resolved asynchronously
  # in the order they are added to the tree. Parents are guaranteed
  # to be resolved before their children. The result of each promise
  # is passes to each of its children when the child resolves. When
  # a promise is rejected all its children will be summarily rejected.
  # A promise added to a rejected promise will immediately be rejected.
  # A promise that is neither resolved or rejected is pending.
  #
  # @param args [Array] zero or more arguments for the block
  # @param block [Proc] the block to call when attempting fulfillment
  #
  # @see Promise
  # @see http://wiki.commonjs.org/wiki/Promises/A
  def promise(*args, &block)
    return Concurrent::Promise.new(*args, &block)
  end
  module_function :promise
end

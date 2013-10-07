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

  def post(object, &block)
    if object.respond_to?(:post)
      return object.post(&block)
    else
      raise ArgumentError.new('object does not support #post')
    end
  end
  module_function :post

  ## defer

  def defer(*args, &block)
    return Concurrent::Defer.new(*args, &block)
  end
  module_function :defer

  ## future

  def future(*args, &block)
    return Concurrent::Future.new(*args, &block)
  end
  module_function :future

  ## obligation

  def deref(object, timeout = nil)
    if object.respond_to?(:deref)
      return object.deref(timeout)
    elsif object.respond_to?(:value)
      return object.value(timeout)
    else
      raise ArgumentError.new('object does not support #deref')
    end
  end
  module_function :deref

  def pending?(object)
    if object.respond_to?(:pending?)
      return object.pending?
    else
      raise ArgumentError.new('object does not support #pending?')
    end
  end
  module_function :pending?

  def fulfilled?(object)
    if object.respond_to?(:fulfilled?)
      return object.fulfilled?
    elsif object.respond_to?(:realized?)
      return object.realized?
    else
      raise ArgumentError.new('object does not support #fulfilled?')
    end
  end
  module_function :fulfilled?

  def realized?(object)
    if object.respond_to?(:realized?)
      return object.realized?
    elsif object.respond_to?(:fulfilled?)
      return object.fulfilled?
    else
      raise ArgumentError.new('object does not support #realized?')
    end
  end
  module_function :realized?

  def rejected?(object)
    if object.respond_to?(:rejected?)
      return object.rejected?
    else
      raise ArgumentError.new('object does not support #rejected?')
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

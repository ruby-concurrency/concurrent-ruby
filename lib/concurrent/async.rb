require 'thread'
require 'concurrent/ivar'
require 'concurrent/future'

module Concurrent

  # A mixin module that provides simple asynchronous behavior to any standard
  # class/object or object. 
  #
  #   Scenario:
  #     As a stateful, plain old Ruby class/object
  #     I want safe, asynchronous behavior
  #     So my long-running methods don't block the main thread
  #
  # Stateful, mutable objects must be managed carefully when used asynchronously.
  # But Ruby is an object-oriented language so designing with objects and classes
  # plays to Ruby's strengths and is often more natural to many Ruby programmers.
  # The +Async+ module is a way to mix simple yet powerful asynchronous capabilities
  # into any plain old Ruby object or class. These capabilities provide a reasonable
  # level of thread safe guarantees when used correctly.
  #
  # When this module is mixed into a class or object it provides to new methods:
  # +async+ and +await+. These methods are thread safe with respect to the enclosing
  # object. The former method allows methods to be called asynchronously by posting
  # to the global thread pool. The latter allows a method to be called synchronously
  # on the current thread but does so safely with respect to any pending asynchronous
  # method calls. Both methods return an +Obligation+ which can be inspected for
  # the result of the method call. Calling a method with +async+ will return a
  # +:pending+ +Obligation+ whereas +await+ will return a +:complete+ +Obligation+.
  #
  # Very loosely based on the +async+ and +await+ keywords in C#.
  #
  # @example Defining an asynchronous class
  #   class Echo
  #     include Concurrent::Async
  #
  #     def echo(msg)
  #       sleep(rand)
  #       print "#{msg}\n"
  #       nil
  #     end
  #   end
  #   
  #   horn = Echo.new
  #   horn.echo('zero') # synchronous, not thread-safe
  #
  #   horn.async.echo('one') # asynchronous, non-blocking, thread-safe
  #   horn.await.echo('two') # synchronous, blocking, thread-safe
  #
  # @example Monkey-patching an existing object
  #   numbers = 1_000_000.times.collect{ rand }
  #   numbers.extend(Concurrent::Async)
  #   
  #   future = numbers.async.max
  #   future.state #=> :pending
  #   
  #   sleep(2)
  #   
  #   future.state #=> :fulfilled
  #   future.value #=> 0.999999138918843
  #
  # @note Thread safe guarantees can only be made when asynchronous method calls
  #       are not mixed with synchronous method calls. Use only synchronous calls
  #       when the object is used exclusively on a single thread. Use only
  #       asynchronous calls when the object is shared between threads.
  #
  # @since 0.6.0
  #
  # @see Concurrent::Obligation
  #
  # @see http://msdn.microsoft.com/en-us/library/hh191443.aspx Asynchronous Programming with Async and Await (C# and Visual Basic)
  # @see http://msdn.microsoft.com/en-us/magazine/jj991977.aspx Best Practices in Asynchronous Programming
  module Async

    # Check for the presence of a method on an object and determine if a given
    # set of arguments matches the required arity.
    #
    # @param [Object] obj the object to check against
    # @param [Symbol] method the method to check the object for
    # @param [Array] args zero or more arguments for the arity check
    #
    # @raise [NameError] the object does not respond to +method+ method
    # @raise [ArgumentError] the given +args+ do not match the arity of +method+
    #
    # @note This check is imperfect because of the way Ruby reports the arity of
    #   methods with a variable number of arguments. It is possible to determine
    #   if too few arguments are given but impossible to determine if too many
    #   arguments are given. This check may also fail to recognize dynamic behavior
    #   of the object, such as methods simulated with +method_missing+.
    #
    # @see http://www.ruby-doc.org/core-2.1.1/Method.html#method-i-arity Method#arity
    # @see http://ruby-doc.org/core-2.1.0/Object.html#method-i-respond_to-3F Object#respond_to?
    # @see http://www.ruby-doc.org/core-2.1.0/BasicObject.html#method-i-method_missing BasicObject#method_missing
    def validate_argc(obj, method, *args)
      argc = args.length
      arity = obj.method(method).arity

      if arity >= 0 && argc != arity
        raise ArgumentError.new("wrong number of arguments (#{argc} for #{arity})")
      elsif arity < 0 && (arity = (arity + 1).abs) > argc
        raise ArgumentError.new("wrong number of arguments (#{argc} for #{arity}..*)")
      end
    end
    module_function :validate_argc

    # Delegates synchronous, thread-safe method calls to the wrapped object.
    #
    # @!visibility private
    class AwaitDelegator # :nodoc:

      # The lock used when delegating methods to the wrapped object.
      attr_reader :mutex

      # Create a new delegator object wrapping the given +delegate+ and
      # protecting it with the given +mutex+.
      #
      # @param [Object] delegate the object to wrap and delegate method calls to
      # @param [Mutex] mutex the mutex lock to use when delegating method calls
      def initialize(delegate, mutex)
        @delegate = delegate
        @mutex = mutex
      end

      # Delegates method calls to the wrapped object. For performance,
      # dynamically defines the given method on the delegator so that
      # all future calls to +method+ will not be directed here.
      #
      # @param [Symbol] method the method being called
      # @param [Array] args zero or more arguments to the method
      #
      # @return [IVar] the result of the method call
      #
      # @raise [NameError] the object does not respond to +method+ method
      # @raise [ArgumentError] the given +args+ do not match the arity of +method+
      def method_missing(method, *args, &block)
        super unless @delegate.respond_to?(method)
        Async::validate_argc(@delegate, method, *args)

        self.define_singleton_method(method) do |*args|
          Async::validate_argc(@delegate, method, *args)
          ivar = Concurrent::IVar.new
          value, reason = nil, nil
          begin
            mutex.synchronize do
              value = @delegate.send(method, *args, &block)
            end
          rescue => reason
            # caught
          ensure
            return ivar.complete(reason.nil?, value, reason)
          end
        end

        self.send(method, *args)
      end
    end

    # Delegates asynchronous, thread-safe method calls to the wrapped object.
    #
    # @!visibility private
    class AsyncDelegator # :nodoc:

      # The lock used when delegating methods to the wrapped object.
      attr_reader :mutex

      # Create a new delegator object wrapping the given +delegate+ and
      # protecting it with the given +mutex+.
      #
      # @param [Object] delegate the object to wrap and delegate method calls to
      # @param [Mutex] mutex the mutex lock to use when delegating method calls
      def initialize(delegate, mutex)
        @delegate = delegate
        @mutex = mutex
      end

      # Delegates method calls to the wrapped object. For performance,
      # dynamically defines the given method on the delegator so that
      # all future calls to +method+ will not be directed here.
      #
      # @param [Symbol] method the method being called
      # @param [Array] args zero or more arguments to the method
      #
      # @return [IVar] the result of the method call
      #
      # @raise [NameError] the object does not respond to +method+ method
      # @raise [ArgumentError] the given +args+ do not match the arity of +method+
      def method_missing(method, *args, &block)
        super unless @delegate.respond_to?(method)
        Async::validate_argc(@delegate, method, *args)

        self.define_singleton_method(method) do |*args|
          Async::validate_argc(@delegate, method, *args)
          Concurrent::Future.execute do
            mutex.synchronize do
              @delegate.send(method, *args, &block)
            end
          end
        end

        self.send(method, *args)
      end
    end

    # Causes the chained method call to be performed asynchronously on the
    # global thread pool. The method called by this method will return a
    # +Future+ object in the +:pending+ state and the method call will have
    # been scheduled on the global thread pool. The final disposition of the
    # method call can be obtained by inspecting the returned +Future+.
    #
    # Before scheduling the method on the global thread pool a best-effort
    # attempt will be made to validate that the method exists on the object
    # and that the given arguments match the arity of the requested function.
    # Due to the dynamic nature of Ruby and limitations of its reflection
    # library, some edge cases will be missed. For more information see
    # the documentation for the +validate_argc+ method.
    #
    # @note The method call is guaranteed to be thread safe  with respect to
    #   all other method calls against the same object that are called with
    #   either +async+ or +await+. The mutable nature of Ruby references
    #   (and object orientation in general) prevent any other thread safety
    #   guarantees. Do NOT mix non-protected method calls with protected
    #   method call. Use ONLY protected method calls when sharing the object
    #   between threads.
    #
    # @return [Concurrent::Future] the pending result of the asynchronous operation
    #
    # @raise [NameError] the object does not respond to +method+ method
    # @raise [ArgumentError] the given +args+ do not match the arity of +method+
    #
    # @see Concurrent::Future
    def async
      @__async_delegator__ ||= AsyncDelegator.new(self, Mutex.new)
    end
    alias_method :future, :async

    # Causes the chained method call to be performed synchronously on the
    # current thread. The method called by this method will return an
    # +IVar+ object in either the +:fulfilled+ or +rejected+ state and the
    # method call will have completed. The final disposition of the
    # method call can be obtained by inspecting the returned +IVar+.
    #
    # Before scheduling the method on the global thread pool a best-effort
    # attempt will be made to validate that the method exists on the object
    # and that the given arguments match the arity of the requested function.
    # Due to the dynamic nature of Ruby and limitations of its reflection
    # library, some edge cases will be missed. For more information see
    # the documentation for the +validate_argc+ method.
    #
    # @note The method call is guaranteed to be thread safe  with respect to
    #   all other method calls against the same object that are called with
    #   either +async+ or +await+. The mutable nature of Ruby references
    #   (and object orientation in general) prevent any other thread safety
    #   guarantees. Do NOT mix non-protected method calls with protected
    #   method call. Use ONLY protected method calls when sharing the object
    #   between threads.
    #
    # @return [Concurrent::IVar] the completed result of the synchronous operation
    #
    # @raise [NameError] the object does not respond to +method+ method
    # @raise [ArgumentError] the given +args+ do not match the arity of +method+
    #
    # @see Concurrent::IVar
    def await
      @__await_delegator__ ||= AwaitDelegator.new(self, async.mutex)
    end
    alias_method :defer, :await
  end
end

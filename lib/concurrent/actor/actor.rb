require 'thread'
require 'observer'

require 'concurrent/actor/postable'
require 'concurrent/atomic/event'
require 'concurrent/obligation'
require 'concurrent/runnable'

module Concurrent

  # Actor-based concurrency is all the rage in some circles. Originally described in
  # 1973, the actor model is a paradigm for creating asynchronous, concurrent objects
  # that is becoming increasingly popular. Much has changed since actors were first
  # written about four decades ago, which has led to a serious fragmentation within
  # the actor community. There is *no* universally accepted, strict definition of
  # "actor" and actor implementations differ widely between languages and libraries.
  # 
  # A good definition of "actor" is:
  # 
  #   An independent, concurrent, single-purpose, computational entity that communicates exclusively via message passing.
  # 
  # The +Concurrent::Actor+ class in this library is based solely on the
  # {http://www.scala-lang.org/api/current/index.html#scala.actors.Actor Actor} trait
  # defined in the Scala standard library. It does not implement all the features of
  # Scala's +Actor+ but its behavior for what *has* been implemented is nearly identical.
  # The excluded features mostly deal with Scala's message semantics, strong typing,
  # and other characteristics of Scala that don't really apply to Ruby.
  # 
  # Unlike many of the abstractions in this library, +Actor+ takes an *object-oriented*
  # approach to asynchronous concurrency, rather than a *functional programming*
  # approach.
  #   
  # Because +Actor+ mixes in the +Concurrent::Runnable+ module subclasses have access to
  # the +#on_error+ method and can override it to implement custom error handling. The
  # +Actor+ base class does not use +#on_error+ so as to avoid conflit with subclasses
  # which override it. Generally speaking, +#on_error+ should not be used. The +Actor+
  # base class provides concictent, reliable, and robust error handling already, and
  # error handling specifics are tied to the message posting method. Incorrect behavior
  # in an +#on_error+ override can lead to inconsistent +Actor+ behavior that may lead
  # to confusion and difficult debugging.
  #   
  # The +Actor+ superclass mixes in the Ruby standard library
  # {http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html Observable}
  # module to provide consistent callbacks upon message processing completion. The normal
  # +Observable+ methods, including +#add_observer+ behave normally. Once an observer
  # is added to an +Actor+ it will be notified of all messages processed *after*
  # addition. Notification will *not* occur for any messages that have already been
  # processed.
  #   
  # Observers will be notified regardless of whether the message processing is successful
  # or not. The +#update+ method of the observer will receive four arguments. The
  # appropriate method signature is:
  #   
  #   def update(time, message, result, reason)
  #   
  # These four arguments represent:
  #   
  # * The time that message processing was completed
  # * An array containing all elements of the original message, in order
  # * The result of the call to +#act+ (will be +nil+ if an exception was raised)
  # * Any exception raised by +#act+ (or +nil+ if message processing was successful)
  #
  # @example Actor Ping Pong
  #   class Ping < Concurrent::Actor
  #   
  #     def initialize(count, pong)
  #       super()
  #       @pong = pong
  #       @remaining = count
  #     end
  #     
  #     def act(msg)
  #   
  #       if msg == :pong
  #         print "Ping: pong\n" if @remaining % 1000 == 0
  #         @pong.post(:ping)
  #   
  #         if @remaining > 0
  #           @pong << :ping
  #           @remaining -= 1
  #         else
  #           print "Ping :stop\n"
  #           @pong << :stop
  #           self.stop
  #         end
  #       end
  #     end
  #   end
  #   
  #   class Pong < Concurrent::Actor
  #   
  #     attr_writer :ping
  #   
  #     def initialize
  #       super()
  #       @count = 0
  #     end
  #   
  #     def act(msg)
  #   
  #       if msg == :ping
  #         print "Pong: ping\n" if @count % 1000 == 0
  #         @ping << :pong
  #         @count += 1
  #   
  #       elsif msg == :stop
  #         print "Pong :stop\n"
  #         self.stop
  #       end
  #     end
  #   end
  #   
  #   pong = Pong.new
  #   ping = Ping.new(10000, pong)
  #   pong.ping = ping
  #   
  #   t1 = ping.run!
  #   t2 = pong.run!
  #   
  #   ping << :pong
  #
  # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
  #
  # @see http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html
  class Actor
    include ::Observable
    include Postable
    include Runnable

    private

    # @!visibility private
    class Poolbox # :nodoc:
      include Postable

      def initialize(queue)
        @queue = queue
      end
    end

    public

    # Create a pool of actors that share a common mailbox.
    #   
    # Every +Actor+ instance operates on its own thread. When one thread isn't enough capacity
    # to manage all the messages being sent to an +Actor+ a *pool* can be used instead. A pool
    # is a collection of +Actor+ instances, all of the same type, that shate a message queue.
    # Messages from other threads are all sent to a single queue against which all +Actor+s
    # load balance.
    #
    # @param [Integer] count the number of actors in the pool
    # @param [Array] args zero or more arguments to pass to each actor in the pool
    #
    # @return [Array] two-element array with the shared mailbox as the first element
    #   and an array of actors as the second element
    #
    # @raise ArgumentError if +count+ is zero or less
    #
    # @example
    #   class EchoActor < Concurrent::Actor
    #     def act(*message)
    #       puts "#{message} handled by #{self}"
    #     end
    #   end
    #     
    #   mailbox, pool = EchoActor.pool(5)
    #   pool.each{|echo| echo.run! }
    #     
    #   10.times{|i| mailbox.post(i) }
    #   #=> [0] handled by #<EchoActor:0x007fc8014fb8b8>
    #   #=> [1] handled by #<EchoActor:0x007fc8014fb890>
    #   #=> [2] handled by #<EchoActor:0x007fc8014fb868>
    #   #=> [3] handled by #<EchoActor:0x007fc8014fb890>
    #   #=> [4] handled by #<EchoActor:0x007fc8014fb840>
    #   #=> [5] handled by #<EchoActor:0x007fc8014fb8b8>
    #   #=> [6] handled by #<EchoActor:0x007fc8014fb8b8>
    #   #=> [7] handled by #<EchoActor:0x007fc8014fb818>
    #   #=> [8] handled by #<EchoActor:0x007fc8014fb890>
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    def self.pool(count, *args, &block)
      warn '[DEPRECATED] `Actor` is deprecated and will be replaced with `ActorContext`.'
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      actors = count.times.collect do
        if block_given?
          actor = self.new(*args, &block.dup)
        else
          actor = self.new(*args)
        end
        actor.instance_variable_set(:@queue, mailbox)
        actor
      end
      return Poolbox.new(mailbox), actors
    end

    protected

    # Actors are defined by subclassing the +Concurrent::Actor+ class and overriding the
    # #act method. The #act method can have any signature/arity but +def act(*args)+
    # is the most flexible and least error-prone signature. The #act method is called in
    # response to a message being post to the +Actor+ instance (see *Behavior* below).
    #
    # @param [Array] message one or more arguments representing the message sent to the
    #   actor via one of the Concurrent::Postable methods
    #
    # @return [Object] the result obtained when the message is successfully processed
    #
    # @raise NotImplementedError unless overridden in the +Actor+ subclass
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    # 
    # @!visibility public
    def act(*message)
      warn '[DEPRECATED] `Actor` is deprecated and will be replaced with `ActorContext`.'
      raise NotImplementedError.new("#{self.class} does not implement #act")
    end

    # @!visibility private
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    def on_run # :nodoc:
      warn '[DEPRECATED] `Actor` is deprecated and will be replaced with `ActorContext`.'
      queue.clear
    end

    # @!visibility private
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    def on_stop # :nodoc:
      queue.clear
      queue.push(:stop)
    end

    # @!visibility private
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    def on_task # :nodoc:
      package = queue.pop
      return if package == :stop
      result = ex = nil
      notifier = package.notifier
      begin
        if notifier.nil? || (notifier.is_a?(Event) && ! notifier.set?)
          result = act(*package.message)
        end
      rescue => ex
        on_error(Time.now, package.message, ex)
      ensure
        if notifier.is_a?(Event) && ! notifier.set?
          package.handler.push(result || ex)
          package.notifier.set
        elsif package.handler.is_a?(IVar)
          package.handler.complete(! result.nil?, result, ex)
        elsif package.handler.respond_to?(:post) && ex.nil?
          package.handler.post(result)
        end

        changed
        notify_observers(Time.now, package.message, result, ex)
      end
    end

    # @!visibility private
    #
    # @deprecated +Actor+ is being replaced with a completely new framework prior to v1.0.0
    def on_error(time, msg, ex) # :nodoc:
    end
  end
end

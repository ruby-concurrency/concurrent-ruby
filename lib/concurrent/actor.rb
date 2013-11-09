require 'thread'
require 'observer'

require 'concurrent/event'
require 'concurrent/obligation'
require 'concurrent/postable'
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
  # The `Concurrent::Actor` class in this library is based solely on the
  # {http://www.scala-lang.org/api/current/index.html#scala.actors.Actor Actor} trait
  # defined in the Scala standard library. It does not implement all the features of
  # Scala's `Actor` but its behavior for what *has* been implemented is nearly identical.
  # The excluded features mostly deal with Scala's message semantics, strong typing,
  # and other characteristics of Scala that don't really apply to Ruby.
  # 
  # Unlike most of the abstractions in this library, `Actor` takes an *object-oriented*
  # approach to asynchronous concurrency, rather than a *functional programming*
  # approach.
  # 
  # Actors are defined by subclassing the `Concurrent::Actor` class and overriding the
  # #act method. The #act method can have any signature/arity but `def act(*args)`
  # is the most flexible and least error-prone signature. The #act method is called in
  # response to a message being post to the `Actor` instance (see *Behavior* below).
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
  class Actor
    include Observable
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

    # Create a pool of actors that share a common mailbox
    def self.pool(count, *args)
      raise ArgumentError.new('count must be greater than zero') unless count > 0
      mailbox = Queue.new
      actors = count.times.collect do
        actor = self.new(*args)
        actor.instance_variable_set(:@queue, mailbox)
        actor
      end
      return Poolbox.new(mailbox), actors
    end

    protected

    # @!visibility public
    def act(*args)
      raise NotImplementedError.new("#{self.class} does not implement #act")
    end

    # @private
    def on_run # :nodoc:
      queue.clear
    end

    # @private
    def on_stop # :nodoc:
      queue.clear
      queue.push(:stop)
    end

    # @private
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
        if package.handler.is_a?(Contract)
          package.handler.complete(result, ex)
        elsif notifier.is_a?(Event) && ! notifier.set?
          package.handler.push(result || ex)
          package.notifier.set
        elsif package.handler.is_a?(Actor) && ex.nil?
          package.handler.post(result)
        end

        changed
        notify_observers(Time.now, package.message, result, ex)
      end
    end

    # @private
    def on_error(time, msg, ex) # :nodoc:
    end
  end
end

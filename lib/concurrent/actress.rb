require 'concurrent/configuration'
require 'concurrent/executor/serialized_execution'
require 'concurrent/ivar'
require 'concurrent/logging'

module Concurrent

  # # Actor model
  #
  # -  Light-weighted.
  # -  Inspired by Akka and Erlang.
  #
  # Actors are sharing a thread-pool by default which makes them very cheap to create and discard.
  # Thousands of actors can be created allowing to brake the program to small maintainable pieces
  # without breaking single responsibility principles.
  #
  # ## What is an actor model?
  #
  # [Wiki](http://en.wikipedia.org/wiki/Actor_model) says:
  # The actor model in computer science is a mathematical model of concurrent computation
  # that treats _actors_ as the universal primitives of concurrent digital computation:
  # in response to a message that it receives, an actor can make local decisions,
  # create more actors, send more messages, and determine how to respond to the next
  # message received.
  #
  # ## Why?
  #
  # Concurrency is hard this is one of many ways how to simplify the problem.
  # It is simpler to reason about actors then about locks (and all their possible states).
  #
  # ## How to use it
  #
  # {include:file:doc/actress/quick.out.rb}
  #
  # ## Messaging
  #
  # Messages are processed in same order as they are sent by a sender. It may interleaved with
  # messages form other senders though. There is also a contract in actor model that
  # messages sent between actors should be immutable. Gems like
  #
  # - [Algebrick](https://github.com/pitr-ch/algebrick) - Typed struct on steroids based on
  #   algebraic types and pattern matching
  # - [Hamster](https://github.com/hamstergem/hamster) - Efficient, Immutable, Thread-Safe
  #   Collection classes for Ruby
  #
  # are very useful.
  #
  # ## Architecture
  #
  # Actors are running on shared thread poll which allows user to create many actors cheaply.
  # Downside is that these actors cannot be directly used to do IO or other blocking operations.
  # Blocking operations could starve the `default_task_pool`. However there are two options:
  #
  # - Create an regular actor which will schedule blocking operations in `global_operation_pool`
  #   (which is intended for blocking operations) sending results back to self in messages.
  # - Create an actor using `global_operation_pool` instead of `global_task_pool`, e.g.
  #   `AnIOActor.spawn name: :blocking, executor: Concurrent.configuration.global_operation_pool`.
  #
  # Each actor is composed from 3 objects:
  #
  # ### {Reference}
  # {include:Actress::Reference}
  #
  # ### {Core}
  # {include:Actress::Core}
  #
  # ### {Context}
  # {include:Actress::Context}
  #
  # ## Speed
  #
  # Simple benchmark Actress vs Celluloid, the numbers are looking good
  # but you know how it is with benchmarks. Source code is in
  # `examples/actress/celluloid_benchmark.rb`. It sends numbers between x actors
  # and adding 1 until certain limit is reached.
  #
  # Benchmark legend:
  #
  # - mes.  - number of messages send between the actors
  # - act.  - number of actors exchanging the messages
  # - impl. - which gem is used
  #
  # ### JRUBY
  #
  #     Rehearsal --------------------------------------------------------
  #     50000    2 actress    24.110000   0.800000  24.910000 (  7.728000)
  #     50000    2 celluloid  28.510000   4.780000  33.290000 ( 14.782000)
  #     50000  500 actress    13.700000   0.280000  13.980000 (  4.307000)
  #     50000  500 celluloid  14.520000  11.740000  26.260000 ( 12.258000)
  #     50000 1000 actress    10.890000   0.220000  11.110000 (  3.760000)
  #     50000 1000 celluloid  15.600000  21.690000  37.290000 ( 18.512000)
  #     50000 1500 actress    10.580000   0.270000  10.850000 (  3.646000)
  #     50000 1500 celluloid  14.490000  29.790000  44.280000 ( 26.043000)
  #     --------------------------------------------- total: 201.970000sec
  #     
  #      mes. act.      impl.      user     system      total        real
  #     50000    2 actress     9.820000   0.510000  10.330000 (  5.735000)
  #     50000    2 celluloid  10.390000   4.030000  14.420000 (  7.494000)
  #     50000  500 actress     9.880000   0.200000  10.080000 (  3.310000)
  #     50000  500 celluloid  12.430000  11.310000  23.740000 ( 11.727000)
  #     50000 1000 actress    10.590000   0.190000  10.780000 (  4.029000)
  #     50000 1000 celluloid  14.950000  23.260000  38.210000 ( 20.841000)
  #     50000 1500 actress    10.710000   0.250000  10.960000 (  3.892000)
  #     50000 1500 celluloid  13.280000  30.030000  43.310000 ( 24.620000) (1)
  #
  # ### MRI 2.1.0
  #
  #     Rehearsal --------------------------------------------------------
  #     50000    2 actress     4.640000   0.080000   4.720000 (  4.852390)
  #     50000    2 celluloid   6.110000   2.300000   8.410000 (  7.898069)
  #     50000  500 actress     6.260000   2.210000   8.470000 (  7.400573)
  #     50000  500 celluloid  10.250000   4.930000  15.180000 ( 14.174329)
  #     50000 1000 actress     6.300000   1.860000   8.160000 (  7.303162)
  #     50000 1000 celluloid  12.300000   7.090000  19.390000 ( 17.962621)
  #     50000 1500 actress     7.410000   2.610000  10.020000 (  8.887396)
  #     50000 1500 celluloid  14.850000  10.690000  25.540000 ( 24.489796)
  #     ---------------------------------------------- total: 99.890000sec
  #     
  #      mes. act.      impl.      user     system      total        real
  #     50000    2 actress     4.190000   0.070000   4.260000 (  4.306386)
  #     50000    2 celluloid   6.490000   2.210000   8.700000 (  8.280051)
  #     50000  500 actress     7.060000   2.520000   9.580000 (  8.518707)
  #     50000  500 celluloid  10.550000   4.980000  15.530000 ( 14.699962)
  #     50000 1000 actress     6.440000   1.870000   8.310000 (  7.571059)
  #     50000 1000 celluloid  12.340000   7.510000  19.850000 ( 18.793591)
  #     50000 1500 actress     6.720000   2.160000   8.880000 (  7.929630)
  #     50000 1500 celluloid  14.140000  10.130000  24.270000 ( 22.775288) (1)
  #
  # *Note (1):* Celluloid is using thread per actor so this bench is creating about 1500
  # native threads. Actress is using constant number of threads.
  module Actress

    require 'concurrent/actress/type_check'
    require 'concurrent/actress/errors'
    require 'concurrent/actress/core_delegations'
    require 'concurrent/actress/envelope'
    require 'concurrent/actress/reference'
    require 'concurrent/actress/core'
    require 'concurrent/actress/context'

    require 'concurrent/actress/ad_hoc'

    # @return [Reference, nil] current executing actor if any
    def self.current
      Thread.current[:__current_actor__]
    end

    # implements ROOT
    class Root
      include Context
      # to allow spawning of new actors, spawn needs to be called inside the parent Actor
      def on_message(message)
        if message.is_a?(Array) && message.first == :spawn
          spawn message[1], &message[2]
        else
          # ignore
        end
      end
    end

    # A root actor, a default parent of all actors spawned outside an actor
    ROOT = Core.new(parent: nil, name: '/', class: Root).reference

    # Spawns a new actor.
    #
    # @example simple
    #   Actress.spawn(AdHoc, :ping1) { -> message { message } }
    #
    # @example complex
    #   Actress.spawn name:     :ping3,
    #                 class:    AdHoc,
    #                 args:     [1]
    #                 executor: Concurrent.configuration.global_task_pool do |add|
    #     lambda { |number| number + add }
    #   end
    #
    # @param block for actress_class instantiation
    # @param args see {.spawn_optionify}
    # @return [Reference] never the actual actor
    def self.spawn(*args, &block)
      experimental_acknowledged? or
          warn '[EXPERIMENTAL] A full release of `Actress`, renamed `Actor`, is expected in the 0.7.0 release.'

      if Actress.current
        Core.new(spawn_optionify(*args).merge(parent: Actress.current), &block).reference
      else
        ROOT.ask([:spawn, spawn_optionify(*args), block]).value
      end
    end

    # as {.spawn} but it'll raise when Actor not initialized properly
    def self.spawn!(*args, &block)
      spawn(spawn_optionify(*args).merge(initialized: ivar = IVar.new), &block).tap { ivar.no_error! }
    end

    # @overload spawn_optionify(actress_class, name, *args)
    #   @param [Context] actress_class to be spawned
    #   @param [String, Symbol] name of the instance, it's used to generate the {Core#path} of the actor
    #   @param args for actress_class instantiation
    # @overload spawn_optionify(opts)
    #   see {Core#initialize} opts
    def self.spawn_optionify(*args)
      if args.size == 1 && args.first.is_a?(Hash)
        args.first
      else
        { class: args[0],
          name:  args[1],
          args:  args[2..-1] }
      end
    end

    # call this to disable experimental warning
    def self.i_know_it_is_experimental!
      @experimental_acknowledged = true
    end

    def self.experimental_acknowledged?
      !!@experimental_acknowledged
    end
  end
end

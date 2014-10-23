require 'concurrent/configuration'
require 'concurrent/executor/serialized_execution'
require 'concurrent/ivar'
require 'concurrent/logging'
require 'concurrent/atomic/synchronization'

module Concurrent
  # TODO https://github.com/celluloid/celluloid/wiki/Supervision-Groups ?
  # TODO Remote actors using DRb
  # TODO IO interoperation
  # TODO un/become

  # TODO doc
  # - what happens if I try to supervise using a normal Context?
  # - how to change behaviours
  # - how to implement custom restarting?
  # - pool for io operations using different executor
  # - document guaranteed ordering

  # {include:file:doc/actor/main.md}
  module Actor

    require 'concurrent/actor/type_check'
    require 'concurrent/actor/errors'
    require 'concurrent/actor/public_delegations'
    require 'concurrent/actor/internal_delegations'
    require 'concurrent/actor/envelope'
    require 'concurrent/actor/reference'
    require 'concurrent/actor/core'
    require 'concurrent/actor/behaviour'
    require 'concurrent/actor/context'

    require 'concurrent/actor/default_dead_letter_handler'
    require 'concurrent/actor/root'
    require 'concurrent/actor/utils'

    # @return [Reference, nil] current executing actor if any
    def self.current
      Thread.current[:__current_actor__]
    end

    @root = Delay.new do
      Core.new(parent: nil, name: '/', class: Root, initialized: ivar = IVar.new).reference.tap do
        ivar.no_error!
      end
    end

    # A root actor, a default parent of all actors spawned outside an actor
    def self.root
      @root.value!
    end

    # Spawns a new actor.
    #
    # @example simple
    #   Actor.spawn(AdHoc, :ping1) { -> message { message } }
    #
    # @example complex
    #   Actor.spawn name:     :ping3,
    #                 class:    AdHoc,
    #                 args:     [1]
    #                 executor: Concurrent.configuration.global_task_pool do |add|
    #     lambda { |number| number + add }
    #   end
    #
    # @param block for context_class instantiation
    # @param args see {.spawn_optionify}
    # @return [Reference] never the actual actor
    def self.spawn(*args, &block)
      if Actor.current
        Core.new(spawn_optionify(*args).merge(parent: Actor.current), &block).reference
      else
        root.ask([:spawn, spawn_optionify(*args), block]).value!
      end
    end

    # as {.spawn} but it'll raise when Actor not initialized properly
    def self.spawn!(*args, &block)
      spawn(spawn_optionify(*args).merge(initialized: ivar = IVar.new), &block).tap { ivar.no_error! }
    end

    # @overload spawn_optionify(context_class, name, *args)
    #   @param [AbstractContext] context_class to be spawned
    #   @param [String, Symbol] name of the instance, it's used to generate the {Core#path} of the actor
    #   @param args for context_class instantiation
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
      warn 'Method Actor.i_know_it_is_experimental! is deprecated. The Actors are no longer experimental.'
    end
  end
end

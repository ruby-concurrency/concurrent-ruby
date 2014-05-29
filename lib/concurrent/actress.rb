require 'concurrent/configuration'
require 'concurrent/executor/serialized_execution'
require 'concurrent/ivar'
require 'concurrent/logging'

module Concurrent

  # Fore more information please see {file:lib/concurrent/actress/doc.md Actress quide}.
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
      Thread.current[:__current_actress__]
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

    # @param block for actress_class instantiation
    # @param args see {.spawn_optionify}
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
    #   @param [String, Symbol] name of the instance, it's used to generate the path of the actor
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

    def self.i_know_it_is_experimental!
      @experimental_acknowledged = true
    end

    def self.experimental_acknowledged?
      !!@experimental_acknowledged
    end
  end
end

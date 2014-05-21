require 'logger'

require 'concurrent/configuration'
require 'concurrent/executor/one_by_one'
require 'concurrent/ivar'

module Concurrent

  # TODO broader description with examples
  #
  # @example ping
  #   class Ping
  #     include Context
  #     def on_message(message)
  #       message
  #     end
  #   end
  #   Ping.spawn(:ping1).ask(:m).value #=> :m
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
        case message.first
        when :spawn
          spawn message[1], &message[2]
        else
          # ignore
        end
      end
    end

    # A root actor, a default parent of all actors spawned outside an actor
    ROOT = Core.new(parent: nil, name: '/', class: Root).reference

    # @param block for actress_class instantiation
    def self.spawn(*args, &block)
      if Actress.current
        Core.new(spawn_optionify(*args).merge(parent: Actress.current), &block).reference
      else
        ROOT.ask([:spawn, spawn_optionify(*args), block]).value
      end
    end

    # @overload spawn_optionify(actress_class, name, *args)
    #   @param [Context] actress_class to be spawned
    #   @param [String, Symbol] name of the instance, it's used to generate the path of the actor
    #   @param args for actress_class instantiation
    # @overload spawn_optionify(opts)
    #   see {Core.new} opts
    def self.spawn_optionify(*args)
      if args.size == 1 && args.first.is_a?(Hash)
        args.first
      else
        { class: args[0],
          name:  args[1],
          args:  args[2..-1] }
      end
    end
  end
end

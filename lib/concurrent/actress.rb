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
          spawn *message[1..2], *message[3], &message[4]
        else
          # ignore
        end
      end
    end

    # A root actor, a default parent of all actors spawned outside an actor
    ROOT = Core.new(nil, '/', Root).reference

    # @param [Context] actress_class to be spawned
    # @param [String, Symbol] name of the instance, it's used to generate the path of the actor
    # @param args for actress_class instantiation
    # @param block for actress_class instantiation
    def self.spawn(actress_class, name, *args, &block)
      if Actress.current
        Core.new(Actress.current, name, actress_class, *args, &block).reference
      else
        ROOT.ask([:spawn, actress_class, name, args, block]).value
      end
    end
  end
end

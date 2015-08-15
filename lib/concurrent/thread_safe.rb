require 'concurrent/utility/engine'
require 'concurrent/thread_safe/synchronized_delegator'
require 'concurrent/map'
require 'concurrent/thread_safe/util'

module Concurrent

  # Various classes within allows for +nil+ values to be stored,
  # so a special +NULL+ token is required to indicate the "nil-ness".
  # @!visibility private
  NULL = Object.new

  if Concurrent.on_cruby?

    # Because MRI never runs code in parallel, the existing
    # non-thread-safe structures should usually work fine.

    # @!macro [attach] concurrent_array
    #
    #   A thread-safe subclass of Array. This version locks against the object
    #   itself for every method call, ensuring only one thread can be reading
    #   or writing at a time. This includes iteration methods like `#each`.
    #
    #   @see http://ruby-doc.org/core-2.2.0/Array.html Ruby standard library `Array`
    class Array < ::Array; end

    # @!macro [attach] concurrent_hash
    #
    #   A thread-safe subclass of Hash. This version locks against the object
    #   itself for every method call, ensuring only one thread can be reading
    #   or writing at a time. This includes iteration methods like `#each`.
    #
    #   @see http://ruby-doc.org/core-2.2.0/Hash.html Ruby standard library `Hash`
    class Hash < ::Hash; end

  elsif Concurrent.on_jruby?
    require 'jruby/synchronized'

    # @!macro concurrent_array
    class Array < ::Array
      include JRuby::Synchronized
    end

    # @!macro concurrent_hash
    class Hash < ::Hash
      include JRuby::Synchronized
    end

  elsif Concurrent.on_rbx?
    require 'monitor'

    # @!macro concurrent_array
    class Array < ::Array; end

    # @!macro concurrent_hash
    class Hash < ::Hash; end

    [Hash, Array].each do |klass|
      klass.class_eval do
        private
        def _mon_initialize
          @_monitor = Monitor.new unless @_monitor # avoid double initialisation
        end

        def self.allocate
          obj = super
          obj.send(:_mon_initialize)
          obj
        end
      end

      klass.superclass.instance_methods(false).each do |method|
        klass.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def #{method}(*args)
            @_monitor.synchronize { super }
          end
        RUBY_EVAL
      end
    end
  end
end

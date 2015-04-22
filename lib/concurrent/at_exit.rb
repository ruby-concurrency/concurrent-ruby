require 'concurrent/logging'
require 'concurrent/synchronization'

module Concurrent

  # Provides ability to add and remove hooks to be run at `Kernel#at_exit`, order is undefined.
  # Each hook is executed at most once.
  class AtExitImplementation < Synchronization::Object
    include Logging

    def initialize(enabled = true)
      super()
      synchronize do
        @hooks   = {}
        @enabled = enabled
      end
    end

    # Add a hook to be run at `Kernel#at_exit`
    # @param [Object] hook_id optionally provide an id, if allready present, hook is replaced
    # @yield the hook
    # @return id of the hook
    def add(hook_id = nil, &hook)
      id = hook_id || hook.object_id
      synchronize { @hooks[id] = hook }
      id
    end

    # Delete a hook by hook_id
    # @return [true, false]
    def delete(hook_id)
      !!synchronize { @hooks.delete hook_id }
    end

    # Is hook with hook_id rpesent?
    # @return [true, false]
    def hook?(hook_id)
      synchronize { @hooks.key? hook_id }
    end

    # @return copy of the hooks
    def hooks
      synchronize { @hooks }.clone
    end

    # install `Kernel#at_exit` callback to execute added hooks
    def install
      synchronize do
        @installed ||= begin
          at_exit { runner }
          true
        end
        self
      end
    end

    # Will it run during `Kernel#at_exit`
    def enabled?
      synchronize { @enabled }
    end

    # Configure if it runs during `Kernel#at_exit`
    def enabled=(value)
      synchronize { @enabled = value }
    end

    # run the hooks manually
    # @return ids of the hooks
    def run
      hooks, _ = synchronize { hooks, @hooks = @hooks, {} }
      hooks.each do |_, hook|
        begin
          hook.call
        rescue => error
          log ERROR, error
        end
      end
      hooks.keys
    end

    private

    def runner
      run if synchronize { @enabled }
    end
  end

  private_constant :AtExitImplementation

  # @see AtExitImplementation
  AtExit = AtExitImplementation.new.install
end

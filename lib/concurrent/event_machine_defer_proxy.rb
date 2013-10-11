require 'concurrent/global_thread_pool'

module Concurrent

  class EventMachineDeferProxy

    def post(*args, &block)
      if args.empty?
        EventMachine.defer(block)
      else
        new_block = proc{ block.call(*args) }
        EventMachine.defer(new_block)
      end
      return true
    end

    def <<(block)
      EventMachine.defer(block)
      return self
    end
  end
end

require 'concurrent/runnable'

module Concurrent

  module Stoppable

    def at_stop(&block)
      raise ArgumentError.new('no block given') unless block_given?
      raise Runnable::LifecycleError.new('#at_stop already set') if @stopper
      @stopper = block
      return self
    end

    protected

    def stopper
      return @stopper
    end
  end
end

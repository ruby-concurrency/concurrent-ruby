require 'concurrent/runnable'

module Concurrent

  module Stoppable

    def before_stop(&block)
      raise ArgumentError.new('no block given') unless block_given?
      raise Runnable::LifecycleError.new('#before_stop already set') if @before_stop_proc
      @before_stop_proc = block
      self
    end

    protected

    def before_stop_proc
      @before_stop_proc
    end
  end
end

require 'thread'

require 'concurrent/obligation'
require 'concurrent/global_thread_pool'

module Concurrent

  class Future
    include Obligation
    behavior(:future)

    def initialize(*args)

      unless block_given?
        @state = :fulfilled
      else
        Fiber.new {
          @value = nil
          @state = :pending
        }.resume
        $GLOBAL_THREAD_POOL.post do
          Thread.pass
          semaphore.synchronize do
            begin
              Fiber.new {
                @value = yield(*args)
                @state = :fulfilled
              }.resume
            rescue Exception => ex
              Fiber.new {
                @state = :rejected
                @reason = ex
              }.resume
            end
          end
        end
      end
    end
  end
end

module Kernel

  def future(*args, &block)
    return Concurrent::Future.new(*args, &block)
  end
  module_function :future
end

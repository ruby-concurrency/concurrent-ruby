require 'concurrent/actor/utils/balancer'

module Concurrent
  module Actor
    module Utils

      # Allows to create a pool of workers and distribute work between them
      # @param [Integer] size number of workers
      # @yield [balancer, index] a block spawning an worker instance. called +size+ times.
      #   The worker should be descendant of AbstractWorker and supervised, see example.
      # @yieldparam [Balancer] balancer to pass to the worker
      # @yieldparam [Integer] index of the worker, usually used in its name
      # @yieldreturn [Reference] the reference of newly created worker
      # @example
      #     class Worker < Concurrent::Actor::Utils::AbstractWorker
      #       def work(message)
      #         p message * 5
      #       end
      #     end
      #
      #     pool = Concurrent::Actor::Utils::Pool.spawn! 'pool', 5 do |balancer, index|
      #       Worker.spawn name: "worker-#{index}", supervise: true, args: [balancer]
      #     end
      #
      #     pool << 'asd' << 2
      #     # prints:
      #     # "asdasdasdasdasd"
      #     # 10
      class Pool < RestartingContext
        def initialize(size, &worker_initializer)
          @balancer = Balancer.spawn name: :balancer, supervise: true
          @workers  = Array.new(size, &worker_initializer.curry[@balancer])
          @workers.each { |w| Type! w, Reference }
        end

        def on_message(message)
          redirect @balancer
        end
      end

      class AbstractWorker < RestartingContext
        def initialize(balancer)
          @balancer = balancer
          @balancer << :subscribe
        end

        def on_message(message)
          work message
        ensure
          @balancer << :subscribe
        end

        def work(message)
          raise NotImplementedError
        end
      end
    end
  end
end

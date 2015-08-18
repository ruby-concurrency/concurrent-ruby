require_relative 'priority_queue_shared'

module Concurrent
  module Collection

    describe RubyNonConcurrentPriorityQueue do

      it_should_behave_like :priority_queue
    end

    if Concurrent.on_jruby?

      describe JavaNonConcurrentPriorityQueue do

        it_should_behave_like :priority_queue
      end
    end

    describe NonConcurrentPriorityQueue do
      if Concurrent.on_jruby?
        it 'inherits from JavaNonConcurrentPriorityQueue' do
          expect(NonConcurrentPriorityQueue.ancestors).to include(JavaNonConcurrentPriorityQueue)
        end
      else
        it 'inherits from RubyNonConcurrentPriorityQueue' do
          expect(NonConcurrentPriorityQueue.ancestors).to include(RubyNonConcurrentPriorityQueue)
        end
      end
    end
  end
end

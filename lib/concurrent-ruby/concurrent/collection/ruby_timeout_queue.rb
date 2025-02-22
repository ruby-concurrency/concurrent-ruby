module Concurrent
  module Collection
    # @!visibility private
    # @!macro ruby_timeout_queue
    class RubyTimeoutQueue < ::Queue
      def initialize(*args)
        if RUBY_VERSION >= '3.2'
          raise "#{self.class.name} is not needed on Ruby 3.2 or later, use ::Queue instead"
        end

        super(*args)

        @mutex = Mutex.new
        @cond_var = ConditionVariable.new
      end

      def push(obj)
        @mutex.synchronize do
          super(obj)
          @cond_var.signal
        end
      end
      alias_method :enq, :push
      alias_method :<<, :push

      def pop(non_block = false, timeout: nil)
        if non_block && timeout
          raise ArgumentError, "can't set a timeout if non_block is enabled"
        end

        if non_block
          super(true)
        elsif @mutex.synchronize { empty? && timed_out?(timeout) { @cond_var.wait(@mutex, timeout) } }
          nil
        else
          super(false)
        end
      end
      alias_method :deq, :pop
      alias_method :shift, :pop

      private

      def timed_out?(timeout)
        return unless timeout

        # https://github.com/ruby/ruby/pull/4256
        if RUBY_VERSION >= '3.1'
          yield.nil?
        else
          deadline = Concurrent.monotonic_time + timeout
          yield
          Concurrent.monotonic_time >= deadline
        end
      end
    end
  end
end

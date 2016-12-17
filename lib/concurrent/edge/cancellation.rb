module Concurrent

  # TODO example: parallel jobs, cancel them all when one fails, clean-up in zip
  # inspired by https://msdn.microsoft.com/en-us/library/dd537607(v=vs.110).aspx
  class Cancellation < Synchronization::Object
    safe_initialization!

    def self.create(future_or_event = Promises.resolvable_event, *resolve_args)
      cancellation = new(future_or_event, *resolve_args)
      [cancellation, cancellation.token]
    end

    private_class_method :new

    def initialize(future, *resolve_args)
      raise ArgumentError, 'future is not Resolvable' unless future.is_a?(Promises::Resolvable)
      @Cancel      = future
      @Token       = Token.new @Cancel.with_hidden_resolvable
      @ResolveArgs = resolve_args
    end

    def token
      @Token
    end

    def cancel(raise_on_repeated_call = true)
      !!@Cancel.resolve(*@ResolveArgs, raise_on_repeated_call)
    end

    def canceled?
      @Cancel.resolved?
    end

    class Token < Synchronization::Object
      safe_initialization!

      def initialize(cancel)
        @Cancel = cancel
      end

      def to_event
        @Cancel.to_event
      end

      def to_future
        @Cancel.to_future
      end

      def on_cancellation(*args, &block)
        @Cancel.on_resolution *args, &block
      end

      def canceled?
        @Cancel.resolved?
      end

      def loop_until_canceled(&block)
        until canceled?
          result = block.call
        end
        result
      end

      def raise_if_canceled(error = CancelledOperationError)
        raise error if canceled?
        self
      end

      def join(*tokens, &block)
        block ||= -> tokens { Promises.any_event(*tokens.map(&:to_event)) }
        self.class.new block.call([@Cancel, *tokens])
      end

    end

    private_constant :Token

    # FIXME (pitr-ch 27-Mar-2016): cooperation with mutex, condition, select etc?
    # TODO (pitr-ch 27-Mar-2016): examples (scheduled to be cancelled in 10 sec)
  end
end

module Concurrent

  # Provides tools for cooperative cancellation.
  # Inspired by <https://msdn.microsoft.com/en-us/library/dd537607(v=vs.110).aspx>
  #
  # @example
  #   # Create new cancellation. `cancellation` is used for cancelling, `token` is passed down to
  #   # tasks for cooperative cancellation
  #   cancellation, token = Concurrent::Cancellation.create
  #   Thread.new(token) do |token|
  #     # Count 1+1 (simulating some other meaningful work) repeatedly
  #     # until the token is cancelled through cancellation.
  #     token.loop_until_canceled { 1+1 }
  #   end
  #   sleep 0.1
  #   cancellation.cancel # Stop the thread by cancelling
  # @!macro warn.edge
  class Cancellation < Synchronization::Object
    safe_initialization!

    # Creates the cancellation object. Returns both the cancellation and the token for convenience.
    # @param [Object] resolve_args resolve_args Arguments which are used when resolve method is called on
    #   resolvable_future_or_event
    # @param [Promises::Resolvable] resolvable_future_or_event resolvable used to track cancellation.
    #   Can be retrieved by `token.to_future` ot `token.to_event`.
    # @example
    #   cancellation, token = Concurrent::Cancellation.create
    # @return [Array(Cancellation, Cancellation::Token)]
    def self.create(resolvable_future_or_event = Promises.resolvable_event, *resolve_args)
      cancellation = new(resolvable_future_or_event, *resolve_args)
      [cancellation, cancellation.token]
    end

    private_class_method :new

    # Returns the token associated with the cancellation.
    # @return [Token]
    def token
      @Token
    end

    # Cancel this cancellation. All executions depending on the token will cooperatively stop.
    # @return [true, false]
    # @raise when cancelling for the second tim
    def cancel(raise_on_repeated_call = true)
      !!@Cancel.resolve(*@ResolveArgs, raise_on_repeated_call)
    end

    # Is the cancellation cancelled?
    # @return [true, false]
    def canceled?
      @Cancel.resolved?
    end

    # Short string representation.
    # @return [String]
    def to_s
      format '%s canceled:%s>', super[0..-2], canceled?
    end

    alias_method :inspect, :to_s

    private

    def initialize(future, *resolve_args)
      raise ArgumentError, 'future is not Resolvable' unless future.is_a?(Promises::Resolvable)
      @Cancel      = future
      @Token       = Token.new @Cancel.with_hidden_resolvable
      @ResolveArgs = resolve_args
    end

    # Created through {Cancellation.create}, passed down to tasks to be able to check if canceled.
    class Token < Synchronization::Object
      safe_initialization!

      # @return [Event] Event which will be resolved when the token is cancelled.
      def to_event
        @Cancel.to_event
      end

      # @return [Future] Future which will be resolved when the token is cancelled with arguments passed in
      #   {Cancellation.create} .
      def to_future
        @Cancel.to_future
      end

      # Is the token cancelled?
      # @return [true, false]
      def canceled?
        @Cancel.resolved?
      end

      # Repeatedly evaluates block until the token is {#canceled?}.
      # @yield to the block repeatedly.
      # @yieldreturn [Object]
      # @return [Object] last result of the block
      def loop_until_canceled(&block)
        until canceled?
          result = block.call
        end
        result
      end

      # Raise error when cancelled
      # @param [#exception] error to be risen
      # @raise the error
      # @return [self]
      def raise_if_canceled(error = CancelledOperationError)
        raise error if canceled?
        self
      end

      # Creates a new token which is cancelled when any of the tokens is.
      # @param [Token] tokens to combine
      # @return [Token] new token
      def join(*tokens, &block)
        block ||= -> token_list { Promises.any_event(*token_list.map(&:to_event)) }
        self.class.new block.call([@Cancel, *tokens])
      end

      # Short string representation.
      # @return [String]
      def to_s
        format '%s canceled:%s>', super[0..-2], canceled?
      end

      alias_method :inspect, :to_s

      private

      def initialize(cancel)
        @Cancel = cancel
      end
    end

    # TODO (pitr-ch 27-Mar-2016): cooperation with mutex, condition, select etc?
    # TODO (pitr-ch 27-Mar-2016): examples (scheduled to be cancelled in 10 sec)
  end
end

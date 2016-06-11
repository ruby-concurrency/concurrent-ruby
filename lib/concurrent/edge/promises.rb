require 'concurrent/promises'

module Concurrent
  module Promises
    module FactoryMethods
      # only proof of concept
      # @return [Future]
      def select(*channels)
        # TODO (pitr-ch 26-Mar-2016): redo, has to be non-blocking
        future do
          # noinspection RubyArgCount
          Channel.select do |s|
            channels.each do |ch|
              s.take(ch) { |value| [value, ch] }
            end
          end
        end
      end
    end

    class Future < Event
      # Zips with selected value form the suplied channels
      # @return [Future]
      def then_select(*channels)
        ZipFuturesPromise.new([self, Concurrent::Promises.select(*channels)], @DefaultExecutor).future
      end

      # @note may block
      # @note only proof of concept
      def then_put(channel)
        on_success(:io) { |value| channel.put value }
      end

      # Asks the actor with its value.
      # @return [Future] new future with the response form the actor
      def then_ask(actor)
        self.then { |v| actor.ask(v) }.flat
      end

      # TODO (pitr-ch 14-Mar-2016): document, and move to core
      def run(terminated = Promises.future)
        on_completion do |success, value, reason|
          if success
            if value.is_a?(Future)
              value.run terminated
            else
              terminated.success value
            end
          else
            terminated.fail reason
          end
        end
      end

      include Enumerable

      def each(&block)
        each_body self.value, &block
      end

      def each!(&block)
        each_body self.value!, &block
      end

      private

      def each_body(value, &block)
        (value.nil? ? [nil] : Array(value)).each(&block)
      end

    end
  end

  # inspired by https://msdn.microsoft.com/en-us/library/dd537607(v=vs.110).aspx
  class Cancellation < Synchronization::Object
    safe_initialization!

    def self.create(future_or_event = Promises.completable_event, *complete_args)
      [(i = new(future_or_event, *complete_args)), i.token]
    end

    private_class_method :new

    def initialize(future, *complete_args)
      raise ArgumentError, 'future is not Completable' unless future.is_a?(Promises::Completable)
      @Cancel       = future
      @Token        = Token.new @Cancel.with_hidden_completable
      @CompleteArgs = complete_args
    end

    def token
      @Token
    end

    def cancel
      try_cancel or raise MultipleAssignmentError, 'cannot cancel twice'
    end

    def try_cancel
      !!@Cancel.complete(false)
    end

    def canceled?
      @Cancel.complete?
    end

    class Token < Synchronization::Object
      safe_initialization!

      def initialize(cancel)
        @Cancel = cancel
      end

      def event
        @Cancel
      end

      alias_method :future, :event

      def on_cancellation(*args, &block)
        @Cancel.on_completion *args, &block
      end

      def then(*args, &block)
        @Cancel.chain *args, &block
      end

      def canceled?
        @Cancel.complete?
      end

      def loop_until_canceled(&block)
        until canceled?
          result = block.call
        end
        result
      end

      def raise_if_canceled
        raise CancelledOperationError if canceled?
        self
      end

      def join(*tokens)
        Token.new Promises.any_event(@Cancel, *tokens.map(&:event))
      end

    end

    private_constant :Token

    # TODO (pitr-ch 27-Mar-2016): cooperation with mutex, select etc?
    # TODO (pitr-ch 27-Mar-2016): examples (scheduled to be cancelled in 10 sec)
  end
end

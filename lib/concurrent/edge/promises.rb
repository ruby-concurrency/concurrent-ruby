require 'concurrent/promises'

module Concurrent
  module Promises
    module FactoryMethods
      # only proof of concept
      # @return [Future]
      def select(*channels)
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
end

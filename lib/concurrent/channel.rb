require 'concurrent/actor'
require 'concurrent/stoppable'

module Concurrent

  # `Channel` is a functional programming variation of `Actor`, based very loosely on the
  # *MailboxProcessor* agent in F#. `Actor` is used to create objects that receive messages
  # from other threads then processes those messages based on the behavior of the class.
  # `Channel` creates objects that receive messages and processe them using the block
  # given at construction. `Channel` is implemented as a subclass of `Actor` and supports
  # all message-passing methods of that class. `Channel` also supports pools with a shared
  # mailbox.
  #
  # @see Concurrent::Actor
  # @see Concurrent::Postable
  # @see Concurrent::Runnable
  # @see Concurrent::Stoppable
  #
  # @see {http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx Async and Parallel Design Patterns in F#: Agents}
  # @see {http://msdn.microsoft.com/en-us/library/ee370357.aspx Control.MailboxProcessor<'Msg> Class (F#)}
  class Channel < Actor
    include Stoppable

    def initialize(&block)
      raise ArgumentError.new('no block given') unless block_given?
      super()
      @task = block
    end

    protected

    def on_stop # :nodoc:
      before_stop_proc.call if before_stop_proc
      super
    end

    private

    def act(*message)
      return @task.call(*message)
    end
  end
end

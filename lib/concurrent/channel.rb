require 'concurrent/actor'
require 'concurrent/stoppable'

module Concurrent

  # +Channel+ is a functional programming variation of +Actor+, based very loosely on the
  # *MailboxProcessor* agent in F#. +Actor+ is used to create objects that receive messages
  # from other threads then processes those messages based on the behavior of the class.
  # +Channel+ creates objects that receive messages and processe them using the block
  # given at construction. +Channel+ is implemented as a subclass of +Actor+ and supports
  # all message-passing methods of that class. +Channel+ also supports pools with a shared
  # mailbox.
  #
  # @example Basic usage
  #   channel = Concurrent::Channel.new do |msg|
  #     sleep(1)
  #     puts "#{msg}\n"
  #   end
  #   
  #   channel.run! => #<Thread:0x007fa123d95fc8 sleep>
  #   
  #   channel.post("Hello, World!") => 1
  #   # wait...
  #   => Hello, World!
  #   
  #   future = channel.post? "Don't Panic." => #<Concurrent::IVar:0x007fa123d6d9d8 @state=:pending...
  #   future.pending? => true
  #   # wait...
  #   => "Don't Panic."
  #   future.fulfilled? => true
  #   
  #   channel.stop => true  
  #
  # @note +Actor+ is being replaced with a completely new framework prior to v1.0.0.
  #       Subsequently +Channel+ will be rewritten to no longer inherit from +Actor+
  #       and no longer include +Stoppable+. The +forward+ method from +Postable+
  #       will also be deprecated. The +pool+ method will likely be removed as
  #       well (in lieu of an internal thread pool). The other messaging methods
  #       (+post+, +post?+, and +post!+) will remain and will behave as they do
  #       now.
  #   
  # @see http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx Async and Parallel Design Patterns in F#: Agents
  # @see http://msdn.microsoft.com/en-us/library/ee370357.aspx Control.MailboxProcessor<'Msg> Class (F#)
  class Channel < Actor
    include Stoppable

    # Initialize a new object with a block operation to be performed in response
    # to every received message.
    #
    # @yield [message] Removes the next message from the queue and processes it
    # @yieldparam [Array] msg The next message post to the channel
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

    def act(*message) # :nodoc:
      return @task.call(*message)
    end
  end
end

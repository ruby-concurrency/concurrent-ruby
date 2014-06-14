class Counter
  # Include context of an actor which gives this class access to reference and other information
  # about the actor, see CoreDelegations.
  include Concurrent::Actress::Context

  # use initialize as you wish
  def initialize(initial_value)
    @count = initial_value
  end

  # override on_message to define actor's behaviour
  def on_message(message)
    case message
    when Integer
      @count += message
    when :terminate
      terminate!
    else
      raise 'unknown'
    end
  end
end

# Create new actor naming the instance 'first'.
# Return value is a reference to the actor, the actual actor is never returned.
counter = Counter.spawn(:first, 5)

# Tell a message and forget returning self.
counter.tell(1)
counter << 1
# (First counter now contains 7.)

# Send a messages asking for a result.
counter.ask(0).class
counter.ask(0).value

# Terminate the actor.
counter.tell(:terminate)
# Not terminated yet, it takes a while until the message is processed.
counter.terminated?
# Waiting for the termination.
counter.terminated.class
counter.terminated.wait
counter.terminated?
# Any subsequent messages are rejected.
counter.ask(5).wait.rejected?

# Failure on message processing terminates the actor.
counter = Counter.spawn(:first, 0)
counter.ask('boom').wait.rejected?
counter.terminated?


# Lets define an actor creating children actors.
class Node
  include Concurrent::Actress::Context

  def on_message(message)
    case message
    when :new_child
      spawn self.class, :child
    when :how_many_children
      children.size
    when :terminate
      terminate!
    else
      raise 'unknown'
    end
  end
end

# Actors are tracking parent-child relationships
parent = Node.spawn :parent
child  = parent.tell(:new_child).ask!(:new_child)
child.parent
parent.ask!(:how_many_children)

# There is a special root actor which is used for all actors spawned outside any actor.
parent.parent

# Termination of an parent will also terminate all children.
parent.ask('boom').wait #
parent.terminated?
child.terminated?

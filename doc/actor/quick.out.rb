class Adder < Concurrent::Actor::RestartingContext
  def initialize(init)
    @count = init
  end

  def on_message(message)
    case message
    when :add
      @count += 1
    else
      # pass to ErrorsOnUnknownMessage behaviour, which will just fail
      pass
    end
  end
end 

# `supervise: true` makes the actor supervised by root actor
adder = Adder.spawn(name: :adder, supervise: true, args: [1])
    # => #<Concurrent::Actor::Reference /adder (Adder)>
adder.parent
    # => #<Concurrent::Actor::Reference / (Concurrent::Actor::Root)>

# tell and forget
adder.tell(:add) << :add                           # => #<Concurrent::Actor::Reference /adder (Adder)>
# ask to get result
adder.ask!(:add)                                   # => 4
# fail the actor
adder.ask!(:bad) rescue $!                         # => #<Concurrent::Actor::UnknownMessage: :bad>
# actor is restarted with initial values
adder.ask!(:add)                                   # => 2
adder.ask!(:terminate!)                            # => true

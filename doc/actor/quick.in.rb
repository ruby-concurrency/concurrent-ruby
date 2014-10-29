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
end #

# `supervise: true` makes the actor supervised by root actor
adder = Adder.spawn(name: :adder, supervise: true, args: [1])
adder.parent

# tell and forget
adder.tell(:add) << :add
# ask to get result
adder.ask!(:add)
# fail the actor
adder.ask!(:bad) rescue $!
# actor is restarted with initial values
adder.ask!(:add)
adder.ask!(:terminate!)

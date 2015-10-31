
class Master < Concurrent::Actor::RestartingContext
  def initialize
    # for listener to be child of master
    @listener = Listener.spawn(name: 'listener1', supervise: true)
  end

  def on_message(msg)
    command, *args = msg
    case command
    when :listener
      @listener
    when :reset, :terminated, :resumed, :paused
      log(DEBUG) { " got #{msg} from #{envelope.sender}"}
    else
      pass
    end
  end

  # TODO turn this into Behaviour and make it default part of RestartingContext
  def on_event(event)
    event_name, _ = event
    case event_name
    when :resetting, :restarting
      @listener << :terminate!
    when Exception, :paused
      @listener << :pause!
    when :resumed
      @listener << :resume!
    end
  end
end 

class Listener < Concurrent::Actor::RestartingContext
  def initialize
    @number = (rand() * 100).to_i
  end

  def on_message(msg)
    case msg
    when :number
      @number
    else
      pass
    end
  end

end 

master   = Master.spawn(name: 'master', supervise: true)
    # => #<Concurrent::Actor::Reference:0x7ff3aa0d1380 /master (Master)>
listener = master.ask!(:listener)
    # => #<Concurrent::Actor::Reference:0x7ff3aa8776e8 /master/listener1 (Listener)>
listener.ask!(:number)                             # => 73

master << :crash
    # => #<Concurrent::Actor::Reference:0x7ff3aa0d1380 /master (Master)>

sleep 0.1                                          # => 1

# ask for listener again, old one is terminated
listener.ask!(:terminated?)                        # => true
listener = master.ask!(:listener)
    # => #<Concurrent::Actor::Reference:0x7ff3ab147110 /master/listener1 (Listener)>
listener.ask!(:number)                             # => 48

master.ask!(:terminate!)                           # => [true, true]

sleep 0.1                                          # => 0

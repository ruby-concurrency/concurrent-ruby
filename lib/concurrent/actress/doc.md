# Light-weighted implementation of Actors. Inspired by Akka and Erlang.

Actors are sharing a thread-pool by default which makes them very cheap to create and discard.
Thousands of actors can be created allowing to brake the program to small maintainable pieces
without breaking single responsibility principles.

## Quick example
    
    class Counter
      include Context
    
      def initialize(initial_value)
        @count = initial_value
      end
    
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
    
    # create new actor
    counter = Counter.spawn(:test_counter, 5) # => a Reference
    
    # send messages
    counter.tell(1) # => counter
    counter << 1 # => counter
    
    # send messages getting an IVar back for synchronization
    counter.ask(0) # => an ivar
    counter.ask(0).value # => 7
    
    # terminate the actor
    counter.ask(:terminate).wait
    counter.terminated? # => true
    counter.ask(5).wait.rejected? # => true
    
    # failure on message processing will terminate the actor
    counter = Counter.spawn(:test_counter, 0)
    counter.ask('boom').wait.rejected? # => true
    counter.terminated? # => true


    




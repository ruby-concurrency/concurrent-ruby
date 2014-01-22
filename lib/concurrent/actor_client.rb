require 'concurrent/actor'
require 'concurrent/postable'

module Concurrent

  class ActorClient < Actor

    def initialize(recipient, host = 'localhost', port = 8787)
    end

    protected

    def act(*message)
      # send message to ActorServer over DRb
      # process the result
      # let Actor do the rest
    end
  end

  #class ActorClient
    #include Postable

    #def initialize(recipient, host = 'localhost', port = 8787)
      ## this example pulls from Postable's queue then sends over DRb
      ## the thread would have to be replaced with something less brute-force
      ## it may even be an actor itself...
      #@thread = Thread.new do
        #loop do
          #package = queue.pop
          ## examine the Concurrent::Postable::Package object
          ## send the message over DRb
          ## handle the response
        #end
      #end
    #end
  #end
end

require 'concurrent'

class EchoActor < Concurrent::Actor

  protected

  def on_run
    print "///===>>> The #{self.class} server has started\n"
  end

  def act(*message)
    # the first element of message is the text to echo
    #   or an exception to be raised
    # the second (optional) element of message is the number of seconds to sleep

    print "///===>>> #{self.class} received #{message.first}\n"

    sleep( message[1] || 0.1 )

    if message.first.is_a?(Exception)
      raise message.first
    else
      return message
    end
  end
end

puts "Starting the ActorServer ..."
server = Concurrent::ActorServer.new('localhost', 9999)
server.pool(:echo, EchoActor)
server.run!
sleep(0.1) # give it a chance to start

puts "Starting the RemoteActor ..."
client = Concurrent::RemoteActor.new(:echo, host: 'localhost', port: 9999)
client.run!
sleep(0.1) # give it a chance to start

print "\nTesting #post ...\n"
# this method should return the size of the queue and not block
print "\t#post returned: #{client.post('hello world')}\n"
sleep(0.2)

print "\nTesting #post? ...\n"
# this method should return a Contract object and not block
# on fulfillment the #value of the contract should be set
contract = client.post?('foo bar')
print "\tthe current state of the contract is: #{contract.state}\n"
sleep(0.2)
print "\tthe current state of the contract is: #{contract.state}\n"
print "\tthe current value of the contract is: #{contract.value}\n"

print "\nTesting #post? with an exception ...\n"
# this method should return a Contract object and not block
# on rejection the #reason of the contract should be set
contract = client.post?(StandardError.new('foo bar'))
print "\tthe current state of the contract is: #{contract.state}\n"
sleep(0.2)
print "\tthe current state of the contract is: #{contract.state}\n"
print "\tthe current reason of the contract is: #{contract.reason.class}: '#{contract.reason}'\n"

print "\nTesting #post! ...\n"
# this method will block and return the result of the operation
print "\t#post! returned: #{client.post!(5, 'So long and thanks for all the fish')}\n"

print "\nTesting #post! with an exception ...\n"
# this method will block then raise the exception raised by the server
begin
  client.post!(5, StandardError.new('So long and thanks for all the fish'))
  print "\t !!!!! THIS CODE SHOULD NEVER RUN !!!!!\n"
rescue => ex
  print "\tpost! raised the exception #{ex.class}: '#{ex}'\n"
end

print "\nTesting #post! with timeout ...\n"
# this method will block then raise a timeout exception
begin
  # tell the server to wait for one second
  client.post!(0.1, StandardError.new('So long and thanks for all the fish'), 1)
  print "\t !!!!! THIS CODE SHOULD NEVER RUN !!!!!\n"
rescue => ex
  print "\tpost! raised the exception #{ex.class}: '#{ex}'\n"
end
sleep(1) # let the server catch up

print "\nTesting #forward with a local actor...\n"
# this method will not block but will forward the message to a local actor
local = EchoActor.new
local.run!
sleep(0.1)
print "\t#forward returned: #{client.forward(local, 'I am not in danger, Skyler. I am the danger.')}\n"
sleep(0.3)

print "\nWaiting for queued messages to finish ...\n"
sleep(1)

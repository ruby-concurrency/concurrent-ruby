require 'bundler/setup'
require 'concurrent/actor'


class MyUDPServer < Concurrent::Actor::RestartingContext
  @@thread = {}

  def initialize
    super
    puts "started [#{name}]"
    if @@thread[name] == nil
      tell(:start)
    end
  end

  def on_message(msg)
    command, *args = msg
    case command
    when :start then  start()
    when :stop  then  stop()
    when :got
      p args
      if args[0].start_with?('crash')
        raise "arrrrrr"
      end
      
    else
      pass
    end
  end

  def start
    server = UDPSocket.new
    server.setsockopt(:SOCKET, :REUSEADDR, true)
    server.bind('127.0.0.1', 5555)

    @@thread[name] = Thread.new(server) do |server|
      begin
        while true
          p [:loop]
          data, src = server.recvfrom(4096)
          p [:data, data]
          tell( [:got, data, src] )
        end
      rescue Exception => err
        p [:err, err]
      end
    end
  end

  def default_executor
    # this does not do IO no need for io executor
    Concurrent.global_fast_executor
  end

end

a = MyUDPServer.spawn!('udp1')

sleep

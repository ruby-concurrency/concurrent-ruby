require 'concurrent'

require 'drb/drb'

require 'faker'
require 'functional'

namespace :test do

  DRB_URI = 'druby://localhost:12345'

  TCP_HOST = '127.0.0.1'
  TCP_PORT = 12345

  NET_ACL = %w{allow all}

  DEFAULT_COUNT = 100

  desc 'Test DRbAsyncDemux and Reactor with an echo client and server'
  task :drb_demux, [:count] do |t, args|
    args.with_defaults(count: DEFAULT_COUNT)

    count = args[:count].to_i

    # server
    demux = Concurrent::Reactor::DRbAsyncDemux.new(uri: DRB_URI, acl: NET_ACL)
    reactor = Concurrent::Reactor.new(demux)
    reactor.add_handler(:echo) {|message| message }

    puts 'Starting the reactor...'
    t = Thread.new{ reactor.start }

    # client
    there = DRbObject.new_with_uri(DRB_URI)

    good = 0

    duration, result = timer do
      count.times do |i|
        message = Faker::Company.bs
        echo = there.echo(message)
        good += 1 if echo == message
      end
    end

    there = nil

    messages_per_second = count / duration
    success_rate = good / count.to_f * 100.0

    puts "Sent #{count} messages. Received #{good} good responses and #{count - good} bad."
    puts "The total processing time was %0.3f seconds." % duration
    puts "That's %i messages per second with a %0.1f success rate." % [messages_per_second, success_rate]

    # cleanup
    reactor.stop
    sleep(0.1)
    Thread.kill(t)
    sleep(0.1)

    puts "And we're done!"
  end
end

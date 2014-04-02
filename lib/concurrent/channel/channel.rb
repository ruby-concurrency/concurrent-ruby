module Concurrent
  class Channel
    def self.select(*channels)
      probe = Probe.new

      channels.each { |channel| channel.select(probe) }
      probe.value
    end
  end
end
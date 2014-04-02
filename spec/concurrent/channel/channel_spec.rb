require 'spec_helper'

module Concurrent

  describe Channel do

    describe '.select' do

      context 'without timeout' do
        it 'returns the first value available on a channel' do
          channels = [ UnbufferedChannel.new, UnbufferedChannel.new]

          Thread.new { channels[1].push 77 }

          value = Channel.select(*channels)

          value.should eq 77
        end
      end

    end

  end
end

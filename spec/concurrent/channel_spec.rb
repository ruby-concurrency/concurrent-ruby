require 'spec_helper'
require_relative 'postable_shared'
require_relative 'runnable_shared'
require_relative 'stoppable_shared'

module Concurrent

  describe Channel do

    context :runnable do
      subject{ Channel.new{ nil } }
      it_should_behave_like :runnable
    end

    context :stoppable do
      subject do
        task = Channel.new{ nil }
        task.run!
        task
      end
      it_should_behave_like :stoppable
    end

    context :postable do

      let!(:postable_class){ Channel }

      let(:sender) do
        Channel.new do |*message|
          if message.first.is_a?(Exception)
            raise message.first
          else
            message.first
          end
        end
      end

      let(:receiver){ Channel.new{|*message| message.first } }

      it_should_behave_like :postable
    end

    subject{ Channel.new{ nil } }

    context '#initialize' do

      it 'raises an exception if no block is given' do
        expect {
          Channel.new
        }.to raise_error(ArgumentError)
      end
    end

    context '#behavior' do

      it 'calls the block once for each message' do
        @expected = false
        channel = Channel.new{ @expected = true }
        channel.run!
        channel << 42
        sleep(0.1)
        channel.stop
        @expected.should be_true
      end

      it 'passes all arguments to the block' do
        @expected = []
        channel = Channel.new{|*message| @expected = message }
        channel.run!
        channel.post(1,2,3,4,5)
        sleep(0.1)
        channel.stop
        @expected.should eq [1,2,3,4,5]
      end
    end

    context '#pool' do

      it 'passes a duplicate of the block to each channel in the pool' do
        block = proc{ nil }
        block.should_receive(:dup).exactly(5).times.and_return(proc{ nil })
        mbox, pool = Channel.pool(5, &block)
      end
    end
  end
end

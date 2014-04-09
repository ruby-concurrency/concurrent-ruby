require 'spec_helper'

module Concurrent

  describe UnbufferedChannel do

    let!(:channel) { subject }
    let(:probe) { Channel::Probe.new }

    context 'with one thread' do

      context 'without timeout' do

        describe '#push' do
          it 'should block' do
            t = Thread.new { channel.push 5 }
            sleep(0.05)
            t.status.should eq 'sleep'
          end
        end

        describe '#pop' do
          it 'should block' do
            t = Thread.new { channel.pop }
            sleep(0.05)
            t.status.should eq 'sleep'
          end
        end

      end

    end

    context 'cooperating threads' do

      it 'passes the pushed value to thread waiting on pop' do
        result = nil

        Thread.new { channel.push 42 }
        Thread.new { result = channel.pop; }

        sleep(0.1)

        result.should eq 42
      end

      it 'passes the pushed value to only one thread' do
        result = []

        Thread.new { channel.push 37 }
        Thread.new { result << channel.pop }
        Thread.new { result << channel.pop }

        sleep(0.1)

        result.should have(1).items
      end

      it 'gets the pushed value when ready' do
        result = nil

        Thread.new { result = channel.pop; }
        Thread.new { channel.push 57 }

        sleep(0.1)

        result.should eq 57
      end
    end

    describe 'select' do

      it 'does not block' do
        t = Thread.new { channel.select(probe) }

        sleep(0.05)

        t.status.should eq false
      end

      it 'gets notified by writer thread' do
        channel.select(probe)

        Thread.new { channel.push 82 }

        probe.value.should eq 82
      end

      it 'ignores already set probes and waits for a new one' do
        probe.set(27)

        channel.select(probe)

        t = Thread.new { channel.push 72 }

        sleep(0.05)

        t.status.should eq 'sleep'

        new_probe = Channel::Probe.new

        channel.select(new_probe)

        sleep(0.05)

        new_probe.value.should eq 72
      end

    end

    describe 'probe set' do

      it 'has size zero after creation' do
        channel.probe_set_size.should eq 0
      end

      it 'increases size after a select' do
        channel.select(probe)
        channel.probe_set_size.should eq 1
      end

      it 'decreases size after a removal' do
        channel.select(probe)
        channel.remove_probe(probe)
        channel.probe_set_size.should eq 0
      end

    end


  end
end

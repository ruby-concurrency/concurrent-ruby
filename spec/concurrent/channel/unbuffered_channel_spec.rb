require 'spec_helper'

module Concurrent

  describe UnbufferedChannel do

    let!(:channel) { subject } # let is not thread safe, let! creates the object before ensuring uniqueness

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
        Thread.new { result = channel.pop }

        sleep(0.05)

        result.should eq 42
      end
    end

  end
end

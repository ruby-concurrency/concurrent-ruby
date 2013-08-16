require 'spec_helper'

module Concurrent
  class Reactor

    describe TcpSyncDemux, not_on_travis: true do

      subject{ TcpSyncDemux.new }

      after(:each) do
        subject.stop
      end

      context 'shared' do

        context '#initialize' do

          it 'sets the initial state to :stopped' do
            subject.should be_stopped
          end
        end

        context '#start' do

          it 'raises an exception if already started' do
            subject.start

            lambda {
              subject.start
            }.should raise_error(StandardError)
          end
        end

        context '#stop' do
        end

        context '#stopped?' do

          it 'returns true when stopped' do
            subject.start
            sleep(0.1)
            subject.stop
            sleep(0.1)
            subject.should be_stopped
          end

          it 'returns false when running' do
            subject.start
            sleep(0.1)
            subject.should_not be_stopped
          end
        end

        context '#accept' do

          it 'returns a correct EventContext object' do
          end
        end

        context '#respond' do
          pending
        end

        context '#close' do
          pending
        end

        context 'event handling' do
        end
      end

      context 'not shared' do

        context '#initialize' do
          pending
        end

        context '#start' do
          pending
        end

        context '#stop' do
          pending
        end

        context '#stopped?' do
          pending
        end

        context '#accept' do
          pending
        end

        context '#respond' do
          pending
        end

        context '#close' do
          pending
        end
      end
    end
  end
end

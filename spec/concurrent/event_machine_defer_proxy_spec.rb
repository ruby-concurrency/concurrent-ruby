require 'spec_helper'

require 'concurrent/agent'
require 'concurrent/future'
require 'concurrent/goroutine'
require 'concurrent/promise'

module Concurrent

  describe EventMachineDeferProxy do

    subject { EventMachineDeferProxy.new }

    after(:all) do
      $GLOBAL_THREAD_POOL = FixedThreadPool.new(1)
    end

    context '#post' do

      it 'proxies a call without arguments' do
        @expected = false
        EventMachine.run do
          subject.post{ @expected = true }
          sleep(0.1)
          EventMachine.stop
        end
        @expected.should eq true
      end

      it 'proxies a call with arguments' do
        @expected = []
        EventMachine.run do
          subject.post(1,2,3){|*args| @expected = args }
          sleep(0.1)
          EventMachine.stop
        end
        @expected.should eq [1,2,3]
      end

      it 'aliases #<<' do
        @expected = false
        EventMachine.run do
          subject << proc{ @expected = true }
          sleep(0.1)
          EventMachine.stop
        end
        @expected.should eq true
      end
    end

    context 'operation' do

      context 'goroutine' do

        it 'passes all arguments to the block' do
          $GLOBAL_THREAD_POOL = EventMachineDeferProxy.new

          EventMachine.run do

            @expected = nil
            go(1, 2, 3){|a, b, c| @expected = [c, b, a] }
            sleep(0.1)
            @expected.should eq [3, 2, 1]

            EventMachine.stop
          end
        end
      end

      context Agent do

        subject { Agent.new(0) }

        before(:each) do
          Agent.thread_pool = EventMachineDeferProxy.new
        end

        it 'supports fulfillment' do

          EventMachine.run do

            @expected = []
            subject.post{ @expected << 1 }
            subject.post{ @expected << 2 }
            subject.post{ @expected << 3 }
            sleep(0.1)
            @expected.should eq [1,2,3]

            EventMachine.stop
          end
        end

        it 'supports validation' do

          EventMachine.run do

            @expected = nil
            subject.validate{ @expected = 10; true }
            subject.post{ nil }
            sleep(0.1)
            @expected.should eq 10

            EventMachine.stop
          end
        end

        it 'supports rejection' do

          EventMachine.run do

            @expected = nil
            subject.
              on_error(StandardError){|ex| @expected = 1 }.
              on_error(StandardError){|ex| @expected = 2 }.
              on_error(StandardError){|ex| @expected = 3 }
            subject.post{ raise StandardError }
            sleep(0.1)
            @expected.should eq 1

            EventMachine.stop
          end
        end
      end

      context Future do

        before(:each) do
          Future.thread_pool = EventMachineDeferProxy.new
        end

        it 'supports fulfillment' do

          EventMachine.run do

            @a = @b = @c = nil
            f = Future.new(1, 2, 3) do |a, b, c|
              @a, @b, @c = a, b, c
            end
            sleep(0.1)
            [@a, @b, @c].should eq [1, 2, 3]

            sleep(0.1)
            EventMachine.stop
          end
        end
      end

      context Promise do

        before(:each) do
          Promise.thread_pool = EventMachineDeferProxy.new
        end

        context 'fulfillment' do

          it 'passes all arguments to the first promise in the chain' do

            EventMachine.run do

              @a = @b = @c = nil
              p = Promise.new(1, 2, 3) do |a, b, c|
                @a, @b, @c = a, b, c
              end
              sleep(0.1)
              [@a, @b, @c].should eq [1, 2, 3]

              sleep(0.1)
              EventMachine.stop
            end
          end

          it 'passes the result of each block to all its children' do

            EventMachine.run do
              @expected = nil
              Promise.new(10){|a| a * 2 }.then{|result| @expected = result}
              sleep(0.1)
              @expected.should eq 20

              sleep(0.1)
              EventMachine.stop
            end
          end

          it 'sets the promise value to the result if its block' do

            EventMachine.run do

              p = Promise.new(10){|a| a * 2 }.then{|result| result * 2}
              sleep(0.1)
              p.value.should eq 40

              sleep(0.1)
              EventMachine.stop
            end
          end
        end

        context 'rejection' do

          it 'sets the promise reason and error on exception' do

            EventMachine.run do

              p = Promise.new{ raise StandardError.new('Boom!') }
              sleep(0.1)
              p.reason.should be_a(Exception)
              p.reason.should.to_s =~ /Boom!/
              p.should be_rejected

              sleep(0.1)
              EventMachine.stop
            end
          end

          it 'calls the first exception block with a matching class' do

            EventMachine.run do

              @expected = nil
              Promise.new{ raise StandardError }.
                on_error(StandardError){|ex| @expected = 1 }.
                on_error(StandardError){|ex| @expected = 2 }.
                on_error(StandardError){|ex| @expected = 3 }
              sleep(0.1)
              @expected.should eq 1

              sleep(0.1)
              EventMachine.stop
            end
          end

          it 'passes the exception object to the matched block' do

            EventMachine.run do

              @expected = nil
              Promise.new{ raise StandardError }.
                on_error(ArgumentError){|ex| @expected = ex }.
                on_error(LoadError){|ex| @expected = ex }.
                on_error(Exception){|ex| @expected = ex }
              sleep(0.1)
              @expected.should be_a(StandardError)

              sleep(0.1)
              EventMachine.stop
            end
          end
        end
      end
    end
  end
end

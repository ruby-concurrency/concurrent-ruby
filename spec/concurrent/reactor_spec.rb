require 'spec_helper'

module Concurrent

  describe Reactor do

    let(:sync_demux) do
      Class.new {
        def initialize
          @running = false
          @queue = Queue.new
        end
        def run() @running = true; end
        def stop
          @queue.push(:stop)
          @running = false
        end
        def running?() return @running == true; end
        def accept()
          event = @queue.pop
          if event == :stop
            return nil
          else
            return Reactor::EventContext.new(event)
          end
        end
        def respond(result, message) return [result, message]; end
        def send(event) @queue.push(event) end
      }.new
    end

    let(:async_demux) do
      Class.new {
        def initialize() @running = false; end
        def run() @running = true; end
        def stop() @running = false; end
        def running?() return @running == true; end
        def set_reactor(reactor) @reactor = reactor; end
        def send(event) @reactor.handle(event); end
      }.new
    end

    after(:each) do
      Thread.kill(@thread) unless @thread.nil?
    end

    context '#initialize' do

      it 'raises an exception when the demux is not valid' do
        lambda {
          Reactor.new('bogus demux')
        }.should raise_error(ArgumentError)
      end

      it 'sets the initial state to not running' do
        Reactor.new.should_not be_running
      end
    end

    context '#running?' do

      it 'returns true when the reactor is running' do
        reactor = Reactor.new
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.should be_running
        reactor.stop
      end

      it 'returns false when the reactor is stopped' do
        reactor = Reactor.new
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.stop
        sleep(0.1)
        reactor.should_not be_running
      end
    end

    context '#add_handler' do

      it 'raises an exception is the event name is reserved' do
        reactor = Reactor.new
        lambda {
          reactor.add_handler(Reactor::RESERVED_EVENTS.first){ nil }
        }.should raise_error(ArgumentError)
      end

      it 'raises an exception if no block is given' do
        reactor = Reactor.new
        lambda {
          reactor.add_handler('no block given')
        }.should raise_error(ArgumentError)
      end

      it 'returns true if the handler is added' do
        reactor = Reactor.new
        reactor.add_handler('good'){ nil }.should be_true
      end
    end

    context '#remove_handler' do

      it 'returns true if the handler is found and removed' do
        reactor = Reactor.new
        reactor.add_handler('good'){ nil }
        reactor.remove_handler('good').should be_true
      end

      it 'returns false if the handler is not found' do
        reactor = Reactor.new
        reactor.remove_handler('not found').should be_false
      end
    end

    context '#stop_on_signal' do

      if Functional::PLATFORM.mri? && ! Functional::PLATFORM.windows?

        it 'traps each valid signal' do
          Signal.should_receive(:trap).with('USR1')
          Signal.should_receive(:trap).with('USR2')
          reactor = Reactor.new
          reactor.stop_on_signal('USR1', 'USR2')
        end

        it 'raises an exception if given an invalid signal' do
          if Functional::PLATFORM.mri?
            reactor = Reactor.new
            lambda {
              reactor.stop_on_signal('BOGUS')
            }.should raise_error(ArgumentError)
          end
        end

        it 'stops the reactor when it receives a trapped signal' do
          reactor = Reactor.new
          reactor.stop_on_signal('USR1')
          reactor.should_receive(:stop).with(no_args())
          Process.kill('USR1', Process.pid)
          sleep(0.1)
        end
      end
    end

    context '#handle' do

      it 'raises an exception if the demux is synchronous' do
        reactor = Reactor.new(sync_demux)
        lambda {
          reactor.handle('event')
        }.should raise_error(NotImplementedError)
      end

      it 'returns :stopped if the reactor is not running' do
        reactor = Reactor.new
        reactor.handle('event').first.should eq :stopped
      end

      it 'returns :ok and the block result on success' do
        reactor = Reactor.new
        reactor.add_handler(:event){ 10 }
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        result = reactor.handle(:event)
        result.first.should eq :ok
        result.last.should eq 10
        reactor.stop
      end

      it 'returns :ex and the exception on failure' do
        reactor = Reactor.new
        reactor.add_handler(:event){ raise StandardError }
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        result = reactor.handle(:event)
        result.first.should eq :ex
        result.last.should be_a(StandardError)
        reactor.stop
      end

      it 'returns :noop when there is no handler' do
        reactor = Reactor.new
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        result = reactor.handle(:event)
        sleep(0.1)
        result.first.should eq :noop
        reactor.stop
      end

      it 'triggers handlers added after the reactor is runed' do
        @expected = false
        reactor = Reactor.new
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.add_handler(:event){ @expected = true }
        reactor.handle(:event)
        @expected.should be_true
        reactor.stop
      end

      it 'does not trigger an event that was removed' do
        @expected = false
        reactor = Reactor.new
        reactor.add_handler(:event){ @expected = true }
        reactor.remove_handler(:event)
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.handle(:event)
        @expected.should be_false
        reactor.stop
      end
    end

    context '#run' do

      it 'raises an exception if the reactor is already running' do
        reactor = Reactor.new
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        lambda {
          reactor.run
        }.should raise_error(StandardError)
        reactor.stop
      end

      it 'runs the reactor if it is not running' do
        reactor = Reactor.new(async_demux)
        reactor.should_receive(:run_async).with(no_args())
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.should be_running
        reactor.stop

        reactor = Reactor.new(sync_demux)
        reactor.should_receive(:run_sync).with(no_args())
        @thread = Thread.new{ reactor.run }
        sleep(0.1)
        reactor.should be_running
        reactor.stop
      end
    end

    context '#stop' do

      it 'returns if the reactor is not running' do
        reactor = Reactor.new
        reactor.stop.should be_true
      end

      it 'stops the reactor when running and synchronous' do
        reactor = Reactor.new(sync_demux)
        @thread = Thread.new{ sleep(0.1); reactor.stop }
        Thread.pass
        reactor.run
      end

      it 'stops the reactor when running and asynchronous' do
        reactor = Reactor.new(async_demux)
        @thread = Thread.new{ sleep(0.1); reactor.stop }
        Thread.pass
        reactor.run
      end

      it 'stops the reactor when running without a demux' do
        reactor = Reactor.new
        @thread = Thread.new{ sleep(0.1); reactor.stop }
        Thread.pass
        reactor.run
      end
    end

    specify 'synchronous demultiplexing' do

      if Functional::PLATFORM.mri? && ! Functional::PLATFORM.windows?

        demux = sync_demux
        reactor = Concurrent::Reactor.new(demux)

        reactor.should_not be_running

        reactor.add_handler(:foo){ 'Foo' }
        reactor.add_handler(:bar){ 'Bar' }
        reactor.add_handler(:baz){ 'Baz' }
        reactor.add_handler(:fubar){ raise StandardError.new('Boom!') }

        reactor.stop_on_signal('USR1')

        demux.should_receive(:respond).with(:ok, 'Foo')
        demux.send(:foo)

        @thread = Thread.new do
          reactor.run
        end
        @thread.abort_on_exception = true
        sleep(0.1)

        reactor.should be_running

        demux.should_receive(:respond).with(:ok, 'Bar')
        demux.should_receive(:respond).with(:ok, 'Baz')
        demux.should_receive(:respond).with(:noop, anything())
        demux.should_receive(:respond).with(:ex, anything())

        demux.send(:bar)
        demux.send(:baz)
        demux.send(:bogus)
        demux.send(:fubar)

        reactor.should be_running
        sleep(0.1)

        Process.kill('USR1', Process.pid)
        sleep(0.1)

        demux.should_not_receive(:respond).with(:foo, anything())
        demux.send(:foo)
        reactor.should_not be_running
      end
    end

    specify 'asynchronous demultiplexing' do

      if Functional::PLATFORM.mri? && ! Functional::PLATFORM.windows?

        demux = async_demux
        reactor = Concurrent::Reactor.new(demux)

        reactor.should_not be_running

        reactor.add_handler(:foo){ 'Foo' }
        reactor.add_handler(:bar){ 'Bar' }
        reactor.add_handler(:baz){ 'Baz' }
        reactor.add_handler(:fubar){ raise StandardError.new('Boom!') }

        reactor.stop_on_signal('USR2')

        demux.send(:foo).first.should eq :stopped

        @thread = Thread.new do
          reactor.run
        end
        @thread.abort_on_exception = true
        sleep(0.1)

        reactor.should be_running

        demux.send(:foo).should eq [:ok, 'Foo']
        demux.send(:bar).should eq [:ok, 'Bar']
        demux.send(:baz).should eq [:ok, 'Baz']
        demux.send(:bogus).first.should eq :noop
        demux.send(:fubar).first.should eq :ex

        reactor.should be_running

        Process.kill('USR2', Process.pid)
        sleep(0.1)

        demux.send(:foo).first.should eq :stopped
        reactor.should_not be_running
      end
    end
  end
end

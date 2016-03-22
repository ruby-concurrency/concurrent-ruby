require 'concurrent/edge/promises'
require 'thread'

Concurrent.use_stdlib_logger Logger::DEBUG

describe 'Concurrent::Promises' do

  include Concurrent::Promises::FactoryMethods

  describe 'chain_completable' do
    it 'event' do
      b = event
      a = event.chain_completable(b)
      a.complete
      expect(b).to be_completed
    end

    it 'future' do
      b = completable_future
      a = completable_future.chain_completable(b)
      a.success :val
      expect(b).to be_completed
      expect(b.value).to eq :val
    end
  end

  describe '.future' do
    it 'executes' do
      future = future { 1 + 1 }
      expect(future.value!).to eq 2

      future = succeeded_future(1).then { |v| v + 1 }
      expect(future.value!).to eq 2
    end

    it 'executes with args' do
      future = future(1, 2, &:+)
      expect(future.value!).to eq 3

      future = succeeded_future(1).then(1) { |v, a| v + 1 }
      expect(future.value!).to eq 2
    end
  end

  describe '.delay' do

    def behaves_as_delay(delay, value)
      expect(delay.completed?).to eq false
      expect(delay.value!).to eq value
    end

    specify do
      behaves_as_delay delay { 1 + 1 }, 2
      behaves_as_delay succeeded_future(1).delay.then { |v| v + 1 }, 2
      behaves_as_delay delay(1) { |a| a + 1 }, 2
      behaves_as_delay succeeded_future(1).delay.then { |v| v + 1 }, 2
    end
  end

  describe '.schedule' do
    it 'scheduled execution' do
      start  = Time.now.to_f
      queue  = Queue.new
      future = schedule(0.1) { 1 + 1 }.then { |v| queue.push(v); queue.push(Time.now.to_f - start); queue }

      expect(future.value!).to eq queue
      expect(queue.pop).to eq 2
      expect(queue.pop).to be >= 0.09

      start  = Time.now.to_f
      queue  = Queue.new
      future = succeeded_future(1).
          schedule(0.1).
          then { |v| v + 1 }.
          then { |v| queue.push(v); queue.push(Time.now.to_f - start); queue }

      expect(future.value!).to eq queue
      expect(queue.pop).to eq 2
      expect(queue.pop).to be >= 0.09
    end

    it 'scheduled execution in graph' do
      start  = Time.now.to_f
      queue  = Queue.new
      future = future { sleep 0.1; 1 }.
          schedule(0.1).
          then { |v| v + 1 }.
          then { |v| queue.push(v); queue.push(Time.now.to_f - start); queue }

      future.wait!
      expect(future.value!).to eq queue
      expect(queue.pop).to eq 2
      expect(queue.pop).to be >= 0.09
    end

  end

  describe '.event' do
    specify do
      completable_event = event
      one               = completable_event.chain { 1 }
      join              = zip(completable_event).chain { 1 }
      expect(one.completed?).to be false
      completable_event.complete
      expect(one.value!).to eq 1
      expect(join.wait.completed?).to be true
    end
  end

  describe '.future without block' do
    specify do
      completable_future = completable_future()
      one                = completable_future.then(&:succ)
      join               = zip_futures(completable_future).then { |v| v }
      expect(one.completed?).to be false
      completable_future.success 0
      expect(one.value!).to eq 1
      expect(join.wait!.completed?).to be true
      expect(join.value!).to eq 0
    end
  end

  describe '.any_complete' do
    it 'continues on first result' do
      f1 = completable_future
      f2 = completable_future
      f3 = completable_future

      any1 = any_complete(f1, f2)
      any2 = f2 | f3

      f1.success 1
      f2.fail

      expect(any1.value!).to eq 1
      expect(any2.reason).to be_a_kind_of StandardError
    end
  end

  describe '.any_successful' do
    it 'continues on first result' do
      f1 = completable_future
      f2 = completable_future

      any = any_successful(f1, f2)

      f1.fail
      f2.success :value

      expect(any.value!).to eq :value
    end
  end

  describe '.zip' do
    it 'waits for all results' do
      a = future { 1 }
      b = future { 2 }
      c = future { 3 }

      z1 = a & b
      z2 = zip a, b, c
      z3 = zip a
      z4 = zip

      expect(z1.value!).to eq [1, 2]
      expect(z2.value!).to eq [1, 2, 3]
      expect(z3.value!).to eq [1]
      expect(z4.value!).to eq []

      q = Queue.new
      z1.then { |*args| q << args }
      expect(q.pop).to eq [1, 2]

      z1.then { |a, b, c| q << [a, b, c] }
      expect(q.pop).to eq [1, 2, nil]

      z2.then { |a, b, c| q << [a, b, c] }
      expect(q.pop).to eq [1, 2, 3]

      z3.then { |a| q << a }
      expect(q.pop).to eq 1

      z3.then { |*a| q << a }
      expect(q.pop).to eq [1]

      z4.then { |a| q << a }
      expect(q.pop).to eq nil

      z4.then { |*a| q << a }
      expect(q.pop).to eq []

      expect(z1.then { |a, b| a+b }.value!).to eq 3
      expect(z1.then { |a, b| a+b }.value!).to eq 3
      expect(z1.then(&:+).value!).to eq 3
      expect(z2.then { |a, b, c| a+b+c }.value!).to eq 6

      expect(future { 1 }.delay).to be_a_kind_of Concurrent::Promises::Future
      expect(future { 1 }.delay.wait!).to be_completed
      expect(event.complete.delay).to be_a_kind_of Concurrent::Promises::Event
      expect(event.complete.delay.wait).to be_completed

      a = future { 1 }
      b = future { raise 'b' }
      c = future { raise 'c' }

      zip(a, b, c).chain { |*args| q << args }
      expect(q.pop.flatten.map(&:class)).to eq [FalseClass, 0.class, NilClass, NilClass, NilClass, RuntimeError, RuntimeError]
      zip(a, b, c).rescue { |*args| q << args }
      expect(q.pop.map(&:class)).to eq [NilClass, RuntimeError, RuntimeError]

      expect(zip.wait(0.1)).to eq true
    end

    context 'when a future raises an error' do

      let(:a_future) { future { raise 'error' } }

      it 'raises a concurrent error' do
        expect { zip(a_future).value! }.to raise_error(Concurrent::Error)
      end

    end
  end

  describe '.each' do
    specify do
      expect(succeeded_future(nil).each.map(&:inspect)).to eq ['nil']
      expect(succeeded_future(1).each.map(&:inspect)).to eq ['1']
      expect(succeeded_future([1, 2]).each.map(&:inspect)).to eq ['1', '2']
    end
  end

  describe '.zip_events' do
    it 'waits for all and returns event' do
      a = succeeded_future 1
      b = failed_future :any
      c = event.complete

      z2 = zip_events a, b, c
      z3 = zip_events a
      z4 = zip_events

      expect(z2.completed?).to be_truthy
      expect(z3.completed?).to be_truthy
      expect(z4.completed?).to be_truthy
    end
  end

  describe 'Future' do
    it 'has sync and async callbacks' do
      callbacks_tester = ->(future) do
        queue = Queue.new
        future.on_completion(:io) { |result| queue.push("async on_completion #{ result.inspect }") }
        future.on_completion! { |result| queue.push("sync on_completion #{ result.inspect }") }
        future.on_success(:io) { |value| queue.push("async on_success #{ value.inspect }") }
        future.on_success! { |value| queue.push("sync on_success #{ value.inspect }") }
        future.on_failure(:io) { |reason| queue.push("async on_failure #{ reason.inspect }") }
        future.on_failure! { |reason| queue.push("sync on_failure #{ reason.inspect }") }
        future.wait
        [queue.pop, queue.pop, queue.pop, queue.pop].sort
      end
      callback_results = callbacks_tester.call(future { :value })
      expect(callback_results).to eq ["async on_completion [true, :value, nil]",
                                      "async on_success :value",
                                      "sync on_completion [true, :value, nil]",
                                      "sync on_success :value"]

      callback_results = callbacks_tester.call(future { raise 'error' })
      expect(callback_results).to eq ["async on_completion [false, nil, #<RuntimeError: error>]",
                                      "async on_failure #<RuntimeError: error>",
                                      "sync on_completion [false, nil, #<RuntimeError: error>]",
                                      "sync on_failure #<RuntimeError: error>"]
    end

    [:wait, :wait!, :value, :value!, :reason, :result].each do |method_with_timeout|
      it "#{ method_with_timeout } supports setting timeout" do
        start_latch = Concurrent::CountDownLatch.new
        end_latch   = Concurrent::CountDownLatch.new

        future = future do
          start_latch.count_down
          end_latch.wait(1)
        end

        start_latch.wait(1)
        future.send(method_with_timeout, 0.1)
        expect(future).not_to be_completed
        end_latch.count_down
        future.wait
      end
    end


    it 'chains' do
      future0 = future { 1 }.then { |v| v + 2 } # both executed on default FAST_EXECUTOR
      future1 = future0.then_on(:fast) { raise 'boo' } # executed on IO_EXECUTOR
      future2 = future1.then { |v| v + 1 } # will fail with 'boo' error, executed on default FAST_EXECUTOR
      future3 = future1.rescue { |err| err.message } # executed on default FAST_EXECUTOR
      future4 = future0.chain { |success, value, reason| success } # executed on default FAST_EXECUTOR
      future5 = future3.with_default_executor(:fast) # connects new future with different executor, the new future is completed when future3 is
      future6 = future5.then(&:capitalize) # executes on IO_EXECUTOR because default was set to :io on future5
      future7 = future0 & future3
      future8 = future0.rescue { raise 'never happens' } # future0 succeeds so future8'll have same value as future 0

      futures = [future0, future1, future2, future3, future4, future5, future6, future7, future8]
      futures.each &:wait

      table = futures.each_with_index.map do |f, i|
        '%5i %7s %10s %6s %4s %6s' % [i, f.success?, f.value, f.reason,
                                      (f.promise.executor if f.promise.respond_to?(:executor)),
                                      f.default_executor]
      end.unshift('index success      value reason pool d.pool')

      expect(table.join("\n")).to eq <<-TABLE.gsub(/^\s+\|/, '').strip
        |index success      value reason pool d.pool
        |    0    true          3          io     io
        |    1   false               boo fast     io
        |    2   false               boo   io     io
        |    3    true        boo          io     io
        |    4    true       true          io     io
        |    5    true        boo               fast
        |    6    true        Boo        fast   fast
        |    7    true [3, "boo"]                 io
        |    8    true          3          io     io
      TABLE
    end

    it 'constructs promise like tree' do
      # if head of the tree is not constructed with #future but with #delay it does not start execute,
      # it's triggered later by calling wait or value on any of the dependent futures or the delay itself
      three = (head = delay { 1 }).then { |v| v.succ }.then(&:succ)
      four  = three.delay.then(&:succ)

      # meaningful to_s and inspect defined for Future and Promise
      expect(head.to_s).to match /<#Concurrent::Promises::Future:0x[\da-f]+ pending>/
      expect(head.inspect).to(
          match(/<#Concurrent::Promises::Future:0x[\da-f]+ pending blocks:\[<#Concurrent::Promises::ThenPromise:0x[\da-f]+ pending>\]>/))

      # evaluates only up to three, four is left unevaluated
      expect(three.value!).to eq 3
      expect(four).not_to be_completed

      expect(four.value!).to eq 4

      # futures hidden behind two delays trigger evaluation of both
      double_delay = delay { 1 }.delay.then(&:succ)
      expect(double_delay.value!).to eq 2
    end

    it 'allows graphs' do
      head    = future { 1 }
      branch1 = head.then(&:succ)
      branch2 = head.then(&:succ).delay.then(&:succ)
      results = [
          zip(branch1, branch2).then { |b1, b2| b1 + b2 },
          branch1.zip(branch2).then { |b1, b2| b1 + b2 },
          (branch1 & branch2).then { |b1, b2| b1 + b2 }]

      sleep 0.1
      expect(branch1).to be_completed
      expect(branch2).not_to be_completed

      expect(results.map(&:value)).to eq [5, 5, 5]
      expect(zip(branch1, branch2).value!).to eq [2, 3]
    end

    describe '#flat' do
      it 'returns value of inner future' do
        f = future { future { 1 } }.flat.then(&:succ)
        expect(f.value!).to eq 2
      end

      it 'propagates failure of inner future' do
        err = StandardError.new('boo')
        f   = future { failed_future(err) }.flat
        expect(f.reason).to eq err
      end

      it 'it propagates failure of the future which was suppose to provide inner future' do
        f = future { raise 'boo' }.flat
        expect(f.reason.message).to eq 'boo'
      end

      it 'fails if inner value is not a future' do
        f = future { 'boo' }.flat
        expect(f.reason).to be_an_instance_of TypeError

        f = future { completed_event }.flat
        expect(f.reason).to be_an_instance_of TypeError
      end

      it 'propagates requests for values to delayed futures' do
        expect(Concurrent.future { Concurrent.delay { 1 } }.flat.value!(0.1)).to eq 1
      end
    end

    it 'completes future when Exception raised' do
      f = future { raise Exception, 'fail' }
      f.wait 1
      expect(f).to be_completed
      expect(f).to be_failed
      expect { f.value! }.to raise_error(Exception, 'fail')
    end
  end

  describe 'interoperability' do
    it 'with actor' do
      actor = Concurrent::Actor::Utils::AdHoc.spawn :doubler do
        -> v { v * 2 }
      end

      expect(future { 2 }.
                 then_ask(actor).
                 then { |v| v + 2 }.
                 value!).to eq 6
    end

    it 'with channel' do
      ch1 = Concurrent::Channel.new
      ch2 = Concurrent::Channel.new

      result = Concurrent::Promises.select(ch1, ch2)
      ch1.put 1
      expect(result.value!).to eq [1, ch1]


      future { 1+1 }.
          then_put(ch1)
      result = future { '%02d' }.
          then_select(ch1, ch2).
          then { |format, (value, channel)| format format, value }
      expect(result.value!).to eq '02'
    end
  end

  specify do
    expect(future { :v }.value!).to eq :v
  end

end

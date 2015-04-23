require 'concurrent'
require 'thread'

logger                          = Logger.new($stderr)
logger.level                    = Logger::DEBUG
Concurrent.configuration.logger = lambda do |level, progname, message = nil, &block|
  logger.add level, message, progname, &block
end

describe 'Concurrent::Edge futures' do

  describe '.post' do
    it 'executes tasks asynchronously' do
      queue = Queue.new
      value = 12
      Concurrent.post { queue.push(value) }
      Concurrent.post(:io) { queue.push(value) }
      expect(queue.pop).to eq value
      expect(queue.pop).to eq value
    end
  end

  describe '.future' do
    it 'executes' do
      future = Concurrent.future(:immediate) { 1 + 1 }
      expect(future.value).to eq 2
    end
  end

  describe '.delay' do
    it 'delays execution' do
      delay = Concurrent.delay { 1 + 1 }
      expect(delay.completed?).to eq false
      expect(delay.value).to eq 2
    end
  end

  describe '.schedule' do
    it 'scheduled execution' do
      start  = Time.now.to_f
      queue  = Queue.new
      future = Concurrent.schedule(0.1) { 1 + 1 }.then { |v| queue.push(v); queue.push(Time.now.to_f - start); queue }

      expect(future.value).to eq queue
      expect(queue.pop).to eq 2
      expect(queue.pop).to be_between(0.1, 0.2)
    end

    it 'scheduled execution in graph' do
      start  = Time.now.to_f
      queue  = Queue.new
      future = Concurrent.
          future { sleep 0.1; 1 }.
          schedule(0.1).
          then { |v| v + 1 }.
          then { |v| queue.push(v); queue.push(Time.now.to_f - start); queue }

      future.wait!
      expect(future.value).to eq queue
      expect(queue.pop).to eq 2
      expect(queue.pop).to be_between(0.2, 0.3)
    end
  end

  describe '.event' do
    specify do
      completable_event = Concurrent.event
      one               = completable_event.chain { 1 }
      join              = Concurrent.join(completable_event).chain { 1 }
      expect(one.completed?).to be false
      completable_event.complete
      expect(one.value).to eq 1
      expect(join.wait.completed?).to be true
    end
  end

  describe '.future without block' do
    specify do
      completable_future = Concurrent.future
      one                = completable_future.then(&:succ)
      join               = Concurrent.join(completable_future).then { |v| v }
      expect(one.completed?).to be false
      completable_future.success 0
      expect(one.value).to eq 1
      expect(join.wait!.completed?).to be true
      expect(join.value!).to eq 0
    end
  end

  describe '.any' do
    it 'continues on first result' do
      queue = Queue.new
      f1    = Concurrent.future(:io) { queue.pop }
      f2    = Concurrent.future(:io) { queue.pop }

      queue.push(1)
      queue.push(2)

      anys = [Concurrent.any(f1, f2),
              f1 | f2,
              f1.or(f2)]

      anys.each do |any|
        expect(any.value.to_s).to match /1|2/
      end

    end
  end

  describe 'Future' do
    it 'has sync and async callbacks' do
      queue  = Queue.new
      future = Concurrent.future { :value } # executed on FAST_EXECUTOR pool by default
      future.on_completion(:io) { queue.push(:async) } # async callback overridden to execute on IO_EXECUTOR pool
      future.on_completion! { queue.push(:sync) } # sync callback executed right after completion in the same thread-pool

      expect(future.value).to eq :value
      expect([queue.pop, queue.pop].sort).to eq [:async, :sync]
    end

    it 'chains' do
      future0 = Concurrent.future { 1 }.then { |v| v + 2 } # both executed on default FAST_EXECUTOR
      future1 = future0.then(:fast) { raise 'boo' } # executed on IO_EXECUTOR
      future2 = future1.then { |v| v + 1 } # will fail with 'boo' error, executed on default FAST_EXECUTOR
      future3 = future1.rescue { |err| err.message } # executed on default FAST_EXECUTOR
      future4 = future0.chain { |success, value, reason| success } # executed on default FAST_EXECUTOR
      future5 = future3.with_default_executor(:fast) # connects new future with different executor, the new future is completed when future3 is
      future6 = future5.then(&:capitalize) # executes on IO_EXECUTOR because default was set to :io on future5
      future7 = Concurrent.join(future0, future3)
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
      three = (head = Concurrent.delay { 1 }).then { |v| v.succ }.then(&:succ)
      four  = three.delay.then(&:succ)

      # meaningful to_s and inspect defined for Future and Promise
      expect(head.to_s).to match /<#Concurrent::Edge::Future:0x[\da-f]+ pending>/
      expect(head.inspect).to(
          match(/<#Concurrent::Edge::Future:0x[\da-f]+ pending blocks:\[<#Concurrent::Edge::ThenPromise:0x[\da-f]+ pending>\]>/))

      # evaluates only up to three, four is left unevaluated
      expect(three.value).to eq 3
      expect(four).not_to be_completed

      expect(four.value).to eq 4

      # futures hidden behind two delays trigger evaluation of both
      double_delay = Concurrent.delay { 1 }.delay.then(&:succ)
      expect(double_delay.value).to eq 2
    end

    it 'allows graphs' do
      head    = Concurrent.future { 1 }
      branch1 = head.then(&:succ)
      branch2 = head.then(&:succ).delay.then(&:succ)
      results = [
          Concurrent.join(branch1, branch2).then { |b1, b2| b1 + b2 },
          branch1.join(branch2).then { |b1, b2| b1 + b2 },
          (branch1 + branch2).then { |b1, b2| b1 + b2 }]

      sleep 0.1
      expect(branch1).to be_completed
      expect(branch2).not_to be_completed

      expect(results.map(&:value)).to eq [5, 5, 5]
    end

    it 'has flat map' do
      f = Concurrent.future { Concurrent.future { 1 } }.flat.then(&:succ)
      expect(f.value!).to eq 2
    end
  end

  it 'interoperability' do
    skip
    actor = Concurrent::Actor::Utils::AdHoc.spawn :doubler do
      -> v { v * 2 }
    end

    # convert ivar to future
    Concurrent::IVar.class_eval do
      def to_future
        Concurrent.promise.tap do |p|
          with_observer { p.complete fulfilled?, value, reason }
        end.future
      end
    end

    expect(Concurrent.
               future { 2 }.
               then { |v| actor.ask(v).to_future }.
               flat.
               then { |v| v + 2 }.
               value).to eq 6

    # possible simplification with helper
    Concurrent::Future.class_eval do
      def then_ask(actor)
        self.then { |v| actor.ask(v).to_future }.flat
      end
    end

    expect(Concurrent.
               future { 2 }.
               then_ask(actor).
               then { |v| v + 2 }.
               value).to eq 6
  end

end

__END__

puts '-- connecting existing promises'

source  = Concurrent.delay { 1 }
promise = Concurrent.promise
promise.connect_to source
p promise.future.value # 1
# or just
p Concurrent.promise.connect_to(source).value


puts '-- using shortcuts'

include Concurrent # includes Future::Shortcuts

# now methods on Concurrent are accessible directly

p delay { 1 }.value, future { 1 }.value # => 1\n1

promise = promise()
promise.connect_to(future { 3 })
p promise.future.value # 3


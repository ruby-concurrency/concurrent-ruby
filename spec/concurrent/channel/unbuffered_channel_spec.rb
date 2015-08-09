module Concurrent
  module Channel

    describe UnbufferedChannel do

      subject { described_class.new }
      let(:probe) { Channel::Probe.new }

      context 'with one thread' do

        context 'without timeout' do

          describe '#push' do
            it 'should block' do
              t = Thread.new { subject.push 5 }
              t.join(0.1)
              expect(t.status).to eq 'sleep'
            end
          end

          describe '#pop' do
            it 'should block' do
              t = Thread.new { subject.pop }
              t.join(0.1)
              expect(t.status).to eq 'sleep'
            end
          end
        end
      end

      context 'cooperating threads' do

        it 'passes the pushed value to thread waiting on pop' do
          push_latch = Concurrent::CountDownLatch.new(1)
          pop_latch = Concurrent::CountDownLatch.new(1)

          result = nil

          Thread.new { push_latch.wait(1); subject.push(42) }
          Thread.new { push_latch.count_down; result = subject.pop; pop_latch.count_down }

          pop_latch.wait(1)
          expect(result.first).to eq 42
        end

        it 'passes the pushed value to only one thread' do
          result = Concurrent::AtomicFixnum.new(0)

          threads = [
            Thread.new { subject.push 37 },
            Thread.new { subject.pop; result.increment },
            Thread.new { subject.pop; result.increment },
            Thread.new { subject.pop; result.increment }
          ]

          threads.each{|t| t.join(0.1) }

          expect(result.value).to eq(1)
        end

        it 'gets the pushed value when ready' do
          result = nil

          threads = [
            Thread.new { result = subject.pop; },
            Thread.new { subject.push 57 }
          ]

          threads.each{|t| t.join(0.1) }

          expect(result.first).to eq 57
        end
      end

      describe 'select' do

        it 'does not block' do
          t = Thread.new { subject.select(probe) }
          t.join(0.1)

          expect(t.status).to eq false
        end

        it 'gets notified by writer thread' do
          subject.select(probe)

          Thread.new { subject.push 82 }

          expect(probe.value.first).to eq 82
        end

        it 'ignores already set probes and waits for a new one' do
          probe.set(27)

          subject.select(probe)

          t = Thread.new { subject.push 72 }
          t.join(0.1)

          expect(t.status).to eq 'sleep'

          new_probe = Channel::Probe.new

          subject.select(new_probe)
          t.join(0.1)

          expect(new_probe.value.first).to eq 72
        end
      end

      describe 'probe set' do

        it 'has size zero after creation' do
          expect(subject.probe_set_size).to eq 0
        end

        it 'increases size after a select' do
          subject.select(probe)
          expect(subject.probe_set_size).to eq 1
        end

        it 'decreases size after a removal' do
          subject.select(probe)
          subject.remove_probe(probe)
          expect(subject.probe_set_size).to eq 0
        end
      end
    end
  end
end

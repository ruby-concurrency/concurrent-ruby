module Concurrent
  module Channel

    describe BufferedChannel do

      let(:size) { 2 }
      subject { described_class.new(size) }
      let(:probe) { Channel::Probe.new }

      context 'without timeout' do

        describe '#push' do
          it 'adds elements to buffer' do
            expect(subject.buffer_queue_size).to be 0

            subject.push('a')
            subject.push('a')

            expect(subject.buffer_queue_size).to be 2
          end

          it 'should block when buffer is full' do
            subject.push 1
            subject.push 2

            t = Thread.new { subject.push 3 }
            t.join(0.1)
            expect(t.status).to eq 'sleep'
          end

          it 'restarts thread when buffer is no more full' do
            subject.push 'hi'
            subject.push 'foo'

            result = nil

            t = Thread.new { subject.push 'bar'; result = 42 }

            t.join(0.1)
            subject.pop
            t.join(0.1)

            expect(result).to eq 42
          end

          it 'should assign value to a probe if probe set is not empty' do
            subject.select(probe)
            Thread.new { sleep(0.1); subject.push 3 }
            expect(probe.value.first).to eq 3
          end
        end

        describe '#pop' do
          it 'should block if buffer is empty' do
            t = Thread.new { subject.pop }
            t.join(0.1)
            expect(t.status).to eq 'sleep'
          end

          it 'returns value if buffer is not empty' do
            subject.push 1
            result = subject.pop

            expect(result.first).to eq 1
          end

          it 'removes the first value from the buffer' do
            subject.push 'a'
            subject.push 'b'

            expect(subject.pop.first).to eq 'a'
            expect(subject.buffer_queue_size).to eq 1
          end
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
      end

      context 'already set probes' do
        context 'empty buffer' do
          it 'discards already set probes' do
            probe.set('set value')

            subject.select(probe)

            subject.push 27

            expect(subject.buffer_queue_size).to eq 1
            expect(subject.probe_set_size).to eq 0
          end
        end

        context 'empty probe set' do
          it 'discards set probe' do
            probe.set('set value')

            subject.push 82

            subject.select(probe)

            expect(subject.buffer_queue_size).to eq 1

            expect(subject.pop.first).to eq 82
          end
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

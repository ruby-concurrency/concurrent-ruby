module Concurrent

  describe Exchanger do

    describe 'exchange' do

      context 'without timeout' do

        it 'should block' do
          latch = Concurrent::CountDownLatch.new

          t = Thread.new do
            subject.exchange(1)
            latch.count_down
          end

          t.join(0.3)
          expect(latch.count).to eq 1
          t.kill
        end

        it 'should receive the other value' do
          first_value = nil
          second_value = nil

          threads = [
            Thread.new { first_value = subject.exchange(2) },
            Thread.new { second_value = subject.exchange(4) }
          ]

          threads.each {|t| t.join(1) }
          expect(first_value).to eq 4
          expect(second_value).to eq 2
        end

        it 'can be reused' do
          first_value = nil
          second_value = nil

          threads = [
            Thread.new { first_value = subject.exchange(1) },
            Thread.new { second_value = subject.exchange(0) }
          ]

          threads.each {|t| t.join(1) }

          threads = [
            Thread.new { first_value = subject.exchange(10) },
            Thread.new { second_value = subject.exchange(12) }
          ]

          threads.each {|t| t.join(1) }
          expect(first_value).to eq 12
          expect(second_value).to eq 10
        end
      end

      context 'with timeout' do

        it 'should block until timeout' do
          duration = Concurrent::TestHelpers.monotonic_interval do
            subject.exchange(2, 0.1)
          end
          expect(duration).to be_within(0.05).of(0.1)
        end
      end
    end
  end
end

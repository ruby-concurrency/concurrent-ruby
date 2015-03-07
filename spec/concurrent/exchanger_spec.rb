require 'hitimes'

module Concurrent

  describe Exchanger do

    describe 'exchange' do

      context 'without timeout' do

        it 'should block' do
          latch_1 = Concurrent::CountDownLatch.new
          latch_2 = Concurrent::CountDownLatch.new

          t = Thread.new do
            latch_1.count_down
            subject.exchange(1)
            latch_2.count_down
          end

          latch_1.wait(1)
          latch_2.wait(0.1)
          expect(latch_2.count).to eq 1
          t.kill
        end

        it 'should receive the other value' do
          first_value = nil
          second_value = nil

          thread_1 = Thread.new { first_value = subject.exchange(2) }
          thread_2 = Thread.new { second_value = subject.exchange(4) }

          [thread_1, thread_2].each(&:join)
          expect(first_value).to eq 4
          expect(second_value).to eq 2
        end

        it 'can be reused' do
          first_value = nil
          second_value = nil

          thread_1 = Thread.new { first_value = subject.exchange(1) }
          thread_2 = Thread.new { second_value = subject.exchange(0) }

          [thread_1, thread_2].each(&:join)

          thread_1 = Thread.new { first_value = subject.exchange(10) }
          thread_2 = Thread.new { second_value = subject.exchange(12) }

          [thread_1, thread_2].each(&:join)

          expect(first_value).to eq 12
          expect(second_value).to eq 10
        end
      end

      context 'with timeout' do

        it 'should block until timeout' do
          duration = Hitimes::Interval.measure do
            subject.exchange(2, 0.1)
          end
          expect(duration).to be_within(0.05).of(0.1)
        end
      end
    end
  end
end

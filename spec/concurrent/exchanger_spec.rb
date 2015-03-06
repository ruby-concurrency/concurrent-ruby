require 'hitimes'

module Concurrent

  describe Exchanger do

    subject { Exchanger.new }
    let!(:exchanger) { subject } # let is not thread safe, let! creates the object before ensuring uniqueness

    describe 'exchange' do

      context 'without timeout' do

        it 'should block' do
          latch = Concurrent::CountDownLatch.new

          t = Thread.new do
            latch.count_down
            exchanger.exchange(1)
          end

          latch.wait(1)
          expect(t.status).to eq 'sleep'
        end

        it 'should receive the other value' do
          latch = Concurrent::CountDownLatch.new(2)
          first_value = nil
          second_value = nil

          Thread.new do
            first_value = exchanger.exchange(2)
            latch.count_down
          end
          Thread.new do
            second_value = exchanger.exchange(4)
            latch.count_down
          end

          latch.wait(1)
          expect(first_value).to eq 4
          expect(second_value).to eq 2
        end

        it 'can be reused' do
          latch_1 = Concurrent::CountDownLatch.new(2)
          latch_2 = Concurrent::CountDownLatch.new(2)

          first_value = nil
          second_value = nil

          Thread.new do
            first_value = exchanger.exchange(1)
            latch_1.count_down
          end
          Thread.new do
            second_value = exchanger.exchange(0)
            latch_1.count_down
          end

          latch_1.wait(1)

          Thread.new do
            first_value = exchanger.exchange(10)
            latch_2.count_down
          end
          Thread.new do
            second_value = exchanger.exchange(12)
            latch_2.count_down
          end

          latch_2.wait(1)

          expect(first_value).to eq 12
          expect(second_value).to eq 10
        end
      end

      context 'with timeout' do

        it 'should block until timeout' do
          duration = Hitimes::Interval.measure do
            exchanger.exchange(2, 0.1)
          end
          expect(duration).to be_within(0.05).of(0.1)
        end
      end
    end
  end
end

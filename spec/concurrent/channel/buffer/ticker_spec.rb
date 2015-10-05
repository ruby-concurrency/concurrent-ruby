require_relative 'timing_buffer_shared'

module Concurrent::Channel::Buffer

  describe Ticker do

    let(:delay) { 0.1 }
    subject { described_class.new(delay) }

    it_behaves_like :channel_timing_buffer

    context '#take' do
      it 'triggers until closed' do
        expected = 3
        actual = 0
        expected.times { actual += 1 if subject.take.is_a? Concurrent::Channel::Tick }
        expect(actual).to eq expected
      end
    end

    context '#poll' do
      it 'triggers until closed' do
        expected = 3
        actual = 0
        expected.times do
          until subject.poll.is_a?(Concurrent::Channel::Tick)
            actual += 1
          end
        end
      end
    end

    context '#next' do
      it 'triggers until closed' do
        expected = 3
        actual = 0
        expected.times { actual += 1 if subject.next.first.is_a? Concurrent::Channel::Tick }
        expect(actual).to eq expected
      end
    end
  end
end

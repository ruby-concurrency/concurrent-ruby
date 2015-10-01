require_relative 'timing_buffer_shared'

module Concurrent::Channel::Buffer

  describe Timer do

    subject { described_class.new(0) }

    it_behaves_like :channel_timing_buffer

    context '#take' do
      it 'closes automatically on first take' do
        subject = described_class.new(0.1)
        expect(subject.take).to be_truthy
        expect(subject).to be_closed
      end
    end

    context '#poll' do
      it 'closes automatically on first take' do
        subject = described_class.new(0.1)
        loop do
          break if subject.poll != NO_VALUE
        end
        expect(subject).to be_closed
      end
    end

    context '#next' do

      it 'closes automatically on first take' do
        subject = described_class.new(0.1)
        loop do
          value, _ = subject.next
          break if value != NO_VALUE
        end
        expect(subject).to be_closed
      end

      it 'returns false for more on first take' do
        subject = described_class.new(0.1)
        more = true
        loop do
          value, more = subject.next
          break if value != NO_VALUE
        end
        expect(more).to be false
      end
    end
  end
end

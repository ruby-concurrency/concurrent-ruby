require_relative 'timing_buffer_shared'

module Concurrent::Channel::Buffer

  describe Timer do

    let(:delay) { 0.1 }
    subject { described_class.new(0.1) }

    it_behaves_like :channel_timing_buffer

    context '#take' do
      it 'closes automatically on first take' do
        expect(subject.take).to be_truthy
        expect(subject).to be_closed
      end
    end

    context '#poll' do
      it 'closes automatically on first take' do
        loop do
          break if subject.poll != NO_VALUE
        end
        expect(subject).to be_closed
      end
    end

    context '#next' do
      it 'closes automatically on first take' do
        loop do
          value, _ = subject.next
          break if value != NO_VALUE
        end
        expect(subject).to be_closed
      end
    end
  end
end

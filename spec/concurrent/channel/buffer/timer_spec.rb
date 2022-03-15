require_relative 'timing_buffer_shared'

module Concurrent::Channel::Buffer

  RSpec.describe Timer, edge: true do

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
          break if subject.poll != Concurrent::NULL
        end
        expect(subject).to be_closed
      end
    end

    context '#next' do
      it 'closes automatically on first take' do
        loop do
          value, _ = subject.next
          break if value != Concurrent::NULL
        end
        expect(subject).to be_closed
      end

    it 'returns false for more' do
      _, more = subject.next
      expect(more).to be false
    end
    end
  end
end

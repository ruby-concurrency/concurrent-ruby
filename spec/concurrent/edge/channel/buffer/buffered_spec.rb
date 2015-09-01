require_relative 'buffered_shared'

module Concurrent::Edge::Channel::Buffer

  describe Buffered do

    specify { expect(subject).to be_blocking }

    subject { described_class.new(10) }
    it_behaves_like :channel_buffered_buffer

    context '#full?' do

      it 'returns true when full' do
        subject = described_class.new(1)
        subject.put(:foo)
        expect(subject).to be_full
      end
    end

    context '#offer' do

      it 'returns false immediately when full' do
        subject = described_class.new(1)
        subject.put(:foo)
        expect(subject.offer(:bar)).to be false
      end
    end
  end
end

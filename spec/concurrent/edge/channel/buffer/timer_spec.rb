module Concurrent::Edge::Channel::Buffer

  describe Timer do

    subject { described_class.new(0) }

    specify { expect(subject).to be_blocking }

    specify { expect(subject.size).to eq 1 }

    context '#empty?' do
      pending
    end

    context '#full?' do
      pending
    end

    context '#put' do
      pending
    end

    context '#offer' do
      pending
    end

    context '#take' do
      pending
    end

    context '#next' do
      pending
    end

    context '#poll' do
      pending
    end
  end
end

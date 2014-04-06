require 'spec_helper'

module Concurrent

  describe ActorContext do

    let(:described_class) do
      Class.new do
        include ActorContext
      end
    end

    it 'protects #initialize' do
      expect {
        described_class.new
      }.to raise_error(NoMethodError)
    end

    context 'callbacks' do

      subject { described_class.send(:new) }

      specify { subject.should respond_to :on_start }

      specify { subject.should respond_to :on_restart }

      specify { subject.should respond_to :on_shutdown }
    end

    context '#spawn' do

      it 'returns an ActorRef' do
        described_class.spawn.should be_a ActorRef
      end
    end
  end
end

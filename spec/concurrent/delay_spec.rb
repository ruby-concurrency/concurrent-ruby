require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'

module Concurrent

  describe Delay do

    context 'behavior' do

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        delay = Delay.new(opts){ value }
        delay.tap{ delay.value }
      end

      it_should_behave_like :dereferenceable

      # obligation

      let!(:fulfilled_value) { 10 }
      let!(:rejected_reason) { StandardError.new('mojo jojo') }

      let(:pending_subject) do
        Delay.new{ fulfilled_value }
      end

      let(:fulfilled_subject) do
        delay = Delay.new{ fulfilled_value }
        delay.tap{ delay.value }
      end

      let(:rejected_subject) do
        delay = Delay.new{ raise rejected_reason }
        delay.tap{ delay.value }
      end

      it_should_behave_like :obligation
    end

    context '#initialize' do

      it 'sets the state to :pending' do
        Delay.new{ nil }.state.should eq :pending
        Delay.new{ nil }.should be_pending
      end

      it 'raises an exception when no block given' do
        expect {
          Delay.new
        }.to raise_error(ArgumentError)
      end
    end

    context '#value' do

      let(:task){ proc{ nil } }

      it 'does not call the block before #value is called' do
        task.should_not_receive(:call).with(any_args)
        Delay.new(&task)
      end

      it 'calls the block when #value is called' do
        task.should_receive(:call).once.with(any_args).and_return(nil)
        Delay.new(&task).value
      end

      it 'only calls the block once no matter how often #value is called' do
        task.should_receive(:call).once.with(any_args).and_return(nil)
        delay = Delay.new(&task)
        5.times{ delay.value }
      end
    end
  end
end

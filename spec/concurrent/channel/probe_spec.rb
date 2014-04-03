require 'spec_helper'

module Concurrent

  describe Probe do

    let(:probe) { Probe.new }

    describe '#set_unless_assigned' do
      context 'empty probe' do
        it 'assigns the value' do
          probe.set_unless_assigned(32)
          probe.value.should eq 32
        end

        it 'returns true' do
          probe.set_unless_assigned('hi').should eq true
        end
      end

      context 'fulfilled probe' do
        before(:each) { probe.set(27) }

        it 'does not assign the value' do
          probe.set_unless_assigned(88)
          probe.value.should eq 27
        end

        it 'returns false' do
          probe.set_unless_assigned('hello').should eq false
        end
      end

      context 'rejected probe' do
        before(:each) { probe.fail }

        it 'does not assign the value' do
          probe.set_unless_assigned(88)
          probe.should be_rejected
        end

        it 'returns false' do
          probe.set_unless_assigned('hello').should eq false
        end
      end
    end

  end
end

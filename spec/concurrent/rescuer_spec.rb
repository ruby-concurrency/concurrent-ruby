require 'spec_helper'

module Concurrent

  describe Rescuer do

    describe '#matches?' do

      it 'returns true if matches' do
        r = Rescuer.new(ArgumentError)
        r.matches?(ArgumentError.new).should be_true
      end

      it 'returns false if does not match' do
        r = Rescuer.new(ArgumentError)
        r.matches?(StandardError.new).should be_false
      end

    end

    describe '#execute_if_matches' do

      before(:each) { @result = nil }

      context 'match' do

        it 'should execute the block if matches' do
          r = Rescuer.new(StandardError) { @result = 42 }
          r.execute_if_matches(ArgumentError.new)
          @result.should eq 42
        end

        it 'does nothing if block is empty' do
          r = Rescuer.new(StandardError)
          r.execute_if_matches(ArgumentError.new)
          @result.should be_nil
        end

      end

      context 'not matches' do

        it 'should not execute the block' do
          r = Rescuer.new(ArgumentError) { @result = 42 }
          r.execute_if_matches(StandardError.new)
          @result.should be_nil
        end

      end
    end


  end
end

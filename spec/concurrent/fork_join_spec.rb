require 'spec_helper'

module Concurrent

  describe 'join' do

    it 'raises an exception when no block given' do
      expect {
        Concurrent::join
      }.to raise_error(ArgumentError)
    end

    it 'executes fork tasks and returns when they\'re finished' do
      n = 0

      Concurrent::join do
        fork { n += 1 }
        fork { n += 1 }
        fork { n += 1 }
      end

      n.should == 3
    end

    it 'returns values in order' do
      Concurrent::join do
        fork { 1 }
        fork { 2 }
        fork { 3 }
      end.should == [1, 2, 3]
    end

  end

end

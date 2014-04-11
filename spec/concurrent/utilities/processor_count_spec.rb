require 'spec_helper'

module Concurrent

  describe '#processor_count' do

    it 'retuns a positive integer' do
      Concurrent::processor_count.should be_a Integer
      Concurrent::processor_count.should >= 1
    end
  end

  describe '#physical_processor_count' do

    it 'retuns a positive integer' do
      Concurrent::physical_processor_count.should be_a Integer
      Concurrent::physical_processor_count.should >= 1
    end
  end
end

require 'spec_helper'
require 'concurrent/parallel/core_ext'

module Concurrent
  describe Enumerable do
    describe '#parallel' do
      it 'should return a parallel instance' do
        expect([].parallel).to be_a Parallel
      end
    end
  end
end

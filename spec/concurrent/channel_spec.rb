require 'spec_helper'

module Concurrent

  describe Channel do

    it 

    context '#initialize' do

      it 'raises an exception if no block is given' do
        pending
      end
    end

    context '#behavior' do

      #it_should_behave_like :obligation
      it 'should behave like :obligation'

      #it_should_behave_like :postable
      it 'should behave like :postable'

      #it_should_behave_like :runnable
      it 'should behave like :runnable'

      it 'calls the block once for each message'

      it 'passes all arguments to the block'
    end

    context '#pool' do

      it 'passes a duplicate of the block to each channel in the pool'
    end
  end
end

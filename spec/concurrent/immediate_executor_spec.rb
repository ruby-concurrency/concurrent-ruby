require 'spec_helper'

module Concurrent

  describe ImmediateExecutor do

    let(:executor) { ImmediateExecutor.new }

    context "#post" do
      it 'executes the block using the arguments as parameters' do
        result = executor.post(1, 2, 3, 4) { |a, b, c, d| [a, b, c, d] }
        result.should eq [1, 2, 3, 4]
      end
    end

    context "#<<" do

      it "returns true" do
        result = executor << proc { false }
        result.should be_true
      end

      it "executes the passed callable" do
        x = 0

        executor << proc { x = 5 }

        x.should eq 5
      end

    end
  end
end
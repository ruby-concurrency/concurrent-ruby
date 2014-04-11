require 'spec_helper'

module Concurrent

  describe SafeTaskExecutor do

    describe '#execute' do

      context 'happy execution' do

        let(:task) { Proc.new { 42 } }
        let(:executor) { SafeTaskExecutor.new(task) }

        it 'should return success' do
          success, value, reason = executor.execute
          success.should be_true
        end

        it 'should return task value' do
          success, value, reason = executor.execute
          value.should eq 42
        end

        it 'should return a nil reason' do
          success, value, reason = executor.execute
          reason.should be_nil
        end

      end

      context 'failing execution' do

        let(:task) { Proc.new { raise StandardError.new('an error') } }
        let(:executor) { SafeTaskExecutor.new(task) }

        it 'should return false success' do
          success, value, reason = executor.execute
          success.should be_false
        end

        it 'should return a nil value' do
          success, value, reason = executor.execute
          value.should be_nil
        end

        it 'should return the reason' do
          success, value, reason = executor.execute
          reason.should be_a(StandardError)
          reason.message.should eq 'an error'
        end

      end

    end

  end
end

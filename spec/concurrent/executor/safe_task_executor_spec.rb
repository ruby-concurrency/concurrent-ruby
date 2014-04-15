require 'spec_helper'

module Concurrent

  describe SafeTaskExecutor do

    describe '#execute' do

      context 'happy execution' do

        let(:task) { Proc.new { 42 } }
        subject { SafeTaskExecutor.new(task) }

        it 'should return success' do
          success, value, reason = subject.execute
          success.should be_true
        end

        it 'should return task value' do
          success, value, reason = subject.execute
          value.should eq 42
        end

        it 'should return a nil reason' do
          success, value, reason = subject.execute
          reason.should be_nil
        end

        it 'passes all arguments to #execute to the task' do
          expected = nil
          task = proc {|*args| expected = args }
          SafeTaskExecutor.new(task).execute(1, 2, 3)
          expected.should eq [1, 2, 3]
        end

        it 'protectes #execute with a mutex' do
          mutex = double(:mutex)
          Mutex.should_receive(:new).with(no_args).and_return(mutex)
          mutex.should_receive(:synchronize).with(no_args)
          subject.execute
        end
      end

      context 'failing execution' do

        let(:task) { Proc.new { raise StandardError.new('an error') } }
        subject { SafeTaskExecutor.new(task) }

        it 'should return false success' do
          success, value, reason = subject.execute
          success.should be_false
        end

        it 'should return a nil value' do
          success, value, reason = subject.execute
          value.should be_nil
        end

        it 'should return the reason' do
          success, value, reason = subject.execute
          reason.should be_a(StandardError)
          reason.message.should eq 'an error'
        end

        it 'rescues Exception when :rescue_exception is true' do
          task = proc { raise Exception }
          subject = SafeTaskExecutor.new(task, rescue_exception: true)
          expect {
            subject.execute
          }.to_not raise_error
        end

        it 'rescues StandardError when :rescue_exception is false' do
          task = proc { raise StandardError }
          subject = SafeTaskExecutor.new(task, rescue_exception: false)
          expect {
            subject.execute
          }.to_not raise_error

          task = proc { raise Exception }
          subject = SafeTaskExecutor.new(task, rescue_exception: false)
          expect {
            subject.execute
          }.to raise_error(Exception)
        end

        it 'rescues StandardError by default' do
          task = proc { raise StandardError }
          subject = SafeTaskExecutor.new(task)
          expect {
            subject.execute
          }.to_not raise_error

          task = proc { raise Exception }
          subject = SafeTaskExecutor.new(task)
          expect {
            subject.execute
          }.to raise_error(Exception)
        end
      end
    end
  end
end

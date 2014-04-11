require 'spec_helper'

module Concurrent

  describe OptionsParser do

    subject do
      Class.new{ include OptionsParser }.new
    end

    let(:executor){ ImmediateExecutor.new }

    let(:task_pool){ ImmediateExecutor.new }
    let(:operation_pool){ ImmediateExecutor.new }

    context '#get_executor_from' do

      it 'returns the given :executor' do
        subject.get_executor_from(executor: executor).should eq executor
      end

      it 'returns the global operation pool when :operation is true' do
        Concurrent.configuration.should_receive(:global_operation_pool).
          and_return(:operation_pool)
        subject.get_executor_from(operation: true)
      end

      it 'returns the global task pool when :operation is false' do
        Concurrent.configuration.should_receive(:global_task_pool).
          and_return(:task_pool)
        subject.get_executor_from(operation: false)
      end

      it 'returns the global operation pool when :task is false' do
        Concurrent.configuration.should_receive(:global_operation_pool).
          and_return(:operation_pool)
        subject.get_executor_from(task: false)
      end

      it 'returns the global task pool when :task is true' do
        Concurrent.configuration.should_receive(:global_task_pool).
          and_return(:task_pool)
        subject.get_executor_from(task: true)
      end

      it 'returns the global task pool when :executor is nil' do
        Concurrent.configuration.should_receive(:global_task_pool).
          and_return(:task_pool)
        subject.get_executor_from(executor: nil)
      end

      it 'returns the global task pool when no option is given' do
        Concurrent.configuration.should_receive(:global_task_pool).
          and_return(:task_pool)
        subject.get_executor_from
      end

      specify ':executor overrides :operation' do
        subject.get_executor_from(executor: executor, operation: true).
          should eq executor
      end

      specify ':executor overrides :task' do
        subject.get_executor_from(executor: executor, task: true).
          should eq executor
      end

      specify ':operation overrides :task' do
        Concurrent.configuration.should_receive(:global_operation_pool).
          and_return(:operation_pool)
        subject.get_executor_from(operation: true, task: true)
      end
    end
  end
end

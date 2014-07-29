require 'spec_helper'

module Concurrent

  describe OptionsParser do

    let(:executor){ ImmediateExecutor.new }

    let(:task_pool){ ImmediateExecutor.new }
    let(:operation_pool){ ImmediateExecutor.new }

    context '#get_executor_from' do

      it 'returns the given :executor' do
        expect(OptionsParser::get_executor_from(executor: executor)).to eq executor
      end

      it 'returns the global operation pool when :operation is true' do
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(operation: true)
      end

      it 'returns the global task pool when :operation is false' do
        expect(Concurrent.configuration).to receive(:global_task_pool).
          and_return(:task_pool)
        OptionsParser::get_executor_from(operation: false)
      end

      it 'returns the global operation pool when :task is false' do
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(task: false)
      end

      it 'returns the global task pool when :task is true' do
        expect(Concurrent.configuration).to receive(:global_task_pool).
          and_return(:task_pool)
        OptionsParser::get_executor_from(task: true)
      end

      it 'returns nil when :executor is nil' do
        expect(OptionsParser::get_executor_from(executor: nil)).to be_nil
      end

      it 'returns nil task pool when no option is given' do
        expect(OptionsParser::get_executor_from).to be_nil
      end

      specify ':executor overrides :operation' do
        expect(OptionsParser::get_executor_from(executor: executor, operation: true)).
          to eq executor
      end

      specify ':executor overrides :task' do
        expect(OptionsParser::get_executor_from(executor: executor, task: true)).
          to eq executor
      end

      specify ':operation overrides :task' do
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(operation: true, task: true)
      end
    end
  end
end

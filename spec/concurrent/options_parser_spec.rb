module Concurrent

  describe OptionsParser do

    let(:executor){ ImmediateExecutor.new }

    let(:task_pool){ ImmediateExecutor.new }
    let(:operation_pool){ ImmediateExecutor.new }

    context '#get_arguments_from' do

      it 'returns an empty array when opts is not given' do
        args = OptionsParser::get_arguments_from
        expect(args).to be_a Array
        expect(args).to be_empty
      end

      it 'returns an empty array when opts is an empty hash' do
        args = OptionsParser::get_arguments_from({})
        expect(args).to be_a Array
        expect(args).to be_empty
      end

      it 'returns an empty array when there is no :args key' do
        args = OptionsParser::get_arguments_from(foo: 'bar')
        expect(args).to be_a Array
        expect(args).to be_empty
      end

      it 'returns an empty array when the :args key has a nil value' do
        args = OptionsParser::get_arguments_from(args: nil)
        expect(args).to be_a Array
        expect(args).to be_empty
      end

      it 'returns a one-element array when the :args key has a non-array value' do
        args = OptionsParser::get_arguments_from(args: 'foo')
        expect(args).to eq ['foo']
      end

      it 'returns an array when when the :args key has an array value' do
        expected = [1, 2, 3, 4]
        args = OptionsParser::get_arguments_from(args: expected)
        expect(args).to eq expected
      end

      it 'returns the given array when the :args key has a complex array value' do
        expected = [(1..10).to_a, (20..30).to_a, (100..110).to_a]
        args = OptionsParser::get_arguments_from(args: expected)
        expect(args).to eq expected
      end
    end

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

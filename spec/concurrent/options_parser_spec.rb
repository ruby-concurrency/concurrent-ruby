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

      it 'returns the global task pool when :executor is :task' do
        expect(Concurrent.configuration).to receive(:global_task_pool).
          and_return(:task_pool)
        OptionsParser::get_executor_from(executor: :task)
      end

      it 'returns the global operation pool when :executor is :operation' do
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(executor: :operation)
      end

      it 'returns an immediate executor when :executor is :immediate' do
        executor = OptionsParser::get_executor_from(executor: :immediate)
      end

      it 'raises an exception when :executor is an unrecognized symbol' do
        expect {
          OptionsParser::get_executor_from(executor: :bogus)
        }.to raise_error(ArgumentError)
      end

      it 'returns the global operation pool when :operation is true' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(operation: true)
      end

      it 'returns the global task pool when :operation is false' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent.configuration).to receive(:global_task_pool).
          and_return(:task_pool)
        OptionsParser::get_executor_from(operation: false)
      end

      it 'returns the global operation pool when :task is false' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(task: false)
      end

      it 'returns the global task pool when :task is true' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
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
        warn 'deprecated syntax'
        expect(OptionsParser::get_executor_from(executor: executor, operation: true)).
          to eq executor
      end

      specify ':executor overrides :task' do
        warn 'deprecated syntax'
        expect(OptionsParser::get_executor_from(executor: executor, task: true)).
          to eq executor
      end

      specify ':operation overrides :task' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_executor_from(operation: true, task: true)
      end
    end

    context '#get_task_executor_from' do

      it 'returns the global task pool when no :executor option given' do
        expect(Concurrent.configuration).to receive(:global_task_pool).
          and_return(:task_pool)
        OptionsParser::get_task_executor_from({})
      end

      it 'defers to #get_executor_from when an :executor option is given' do
        opts = {executor: :immediate}
        executor = OptionsParser::get_task_executor_from(opts)
        expect(executor).to be_a(ImmediateExecutor)
      end
    end

    context '#get_operation_executor_from' do

      it 'returns the global operation pool when no :executor option given' do
        expect(Concurrent.configuration).to receive(:global_operation_pool).
          and_return(:operation_pool)
        OptionsParser::get_operation_executor_from({})
      end

      it 'defers to #get_executor_from when an :executor option is given' do
        opts = {executor: :immediate}
        executor = OptionsParser::get_operation_executor_from(opts)
        expect(executor).to be_a(ImmediateExecutor)
      end
    end
  end
end

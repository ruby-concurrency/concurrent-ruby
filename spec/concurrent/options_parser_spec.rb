module Concurrent

  describe OptionsParser do

    let(:executor){ ImmediateExecutor.new }

    let(:io_executor){ ImmediateExecutor.new }
    let(:fast_executor){ ImmediateExecutor.new }

    subject { Class.new{ include OptionsParser }.new }

    context '#get_executor_from' do

      it 'returns the given :executor' do
        expect(subject.get_executor_from(executor: executor)).to eq executor
      end

      it 'returns the global io executor when :executor is :io' do
        expect(Concurrent).to receive(:global_io_executor).and_return(:io_executor)
        subject.get_executor_from(executor: :io)
      end

      it 'returns the global fast executor when :executor is :fast' do
        expect(Concurrent).to receive(:global_fast_executor).and_return(:fast_executor)
        subject.get_executor_from(executor: :fast)
      end

      it 'returns an immediate executor when :executor is :immediate' do
        executor = subject.get_executor_from(executor: :immediate)
      end

      it 'raises an exception when :executor is an unrecognized symbol' do
        expect {
          subject.get_executor_from(executor: :bogus)
        }.to raise_error(ArgumentError)
      end

      it 'returns the global fast executor when :operation is true' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent).to receive(:global_fast_executor).
          and_return(:fast_executor)
        subject.get_executor_from(operation: true)
      end

      it 'returns the global io executor when :operation is false' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent).to receive(:global_io_executor).
          and_return(:io_executor)
        subject.get_executor_from(operation: false)
      end

      it 'returns the global fast executor when :task is false' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent).to receive(:global_fast_executor).
          and_return(:fast_executor)
        subject.get_executor_from(task: false)
      end

      it 'returns the global io executor when :task is true' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent).to receive(:global_io_executor).
          and_return(:io_executor)
        subject.get_executor_from(task: true)
      end

      it 'returns nil when :executor is nil' do
        expect(subject.get_executor_from(executor: nil)).to be_nil
      end

      it 'returns nil when no option is given' do
        expect(subject.get_executor_from).to be_nil
      end

      specify ':executor overrides :operation' do
        warn 'deprecated syntax'
        expect(subject.get_executor_from(executor: executor, operation: true)).
          to eq executor
      end

      specify ':executor overrides :task' do
        warn 'deprecated syntax'
        expect(subject.get_executor_from(executor: executor, task: true)).
          to eq executor
      end

      specify ':operation overrides :task' do
        warn 'deprecated syntax'
        expect(Kernel).to receive(:warn).with(anything)
        expect(Concurrent).to receive(:global_fast_executor).
          and_return(:fast_executor)
        subject.get_executor_from(operation: true, task: true)
      end
    end
  end
end

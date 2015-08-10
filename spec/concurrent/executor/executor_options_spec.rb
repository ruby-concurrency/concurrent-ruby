module Concurrent

  describe 'Executor.executor_from_options' do

    let(:executor) { ImmediateExecutor.new }
    let(:io_executor) { ImmediateExecutor.new }
    let(:fast_executor) { ImmediateExecutor.new }

    it 'returns the given :executor' do
      expect(Executor.executor_from_options(executor: executor)).to eq executor
    end

    it 'returns the global io executor when :executor is :io' do
      expect(Concurrent).to receive(:global_io_executor).and_return(:io_executor)
      Executor.executor_from_options(executor: :io)
    end

    it 'returns the global fast executor when :executor is :fast' do
      expect(Concurrent).to receive(:global_fast_executor).and_return(:fast_executor)
      Executor.executor_from_options(executor: :fast)
    end

    it 'returns an immediate executor when :executor is :immediate' do
      executor = Executor.executor_from_options(executor: :immediate)
    end

    it 'raises an exception when :executor is an unrecognized symbol' do
      expect {
        Executor.executor_from_options(executor: :bogus)
      }.to raise_error(ArgumentError)
    end
  end
end

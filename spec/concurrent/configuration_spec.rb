module Concurrent

  describe Configuration do

    before(:each) do
      Concurrent.class_variable_set(
        :@@global_fast_executor,
        Concurrent::Delay.new(executor: :immediate){ Concurrent::ImmediateExecutor.new })
      Concurrent.class_variable_set(
        :@@global_io_executor,
        Concurrent::Delay.new(executor: :immediate){ Concurrent::ImmediateExecutor.new })
      Concurrent.class_variable_set(
        :@@global_timer_set,
        Concurrent::Delay.new(executor: :immediate){ Concurrent::ImmediateExecutor.new })
    end

    after(:each) do
      Concurrent.class_variable_set(
        :@@global_fast_executor,
        Concurrent::Delay.new(executor: :immediate){ Concurrent.new_fast_executor })
      Concurrent.class_variable_set(
        :@@global_io_executor,
        Concurrent::Delay.new(executor: :immediate){ Concurrent.new_io_executor })
      Concurrent.class_variable_set(
        :@@global_timer_set,
        Concurrent::Delay.new(executor: :immediate){ Concurrent::TimerSet.new })
    end

    it 'creates a global timer pool' do
      expect(Concurrent.configuration.global_timer_set).not_to be_nil
      expect(Concurrent.configuration.global_timer_set).to respond_to(:post)
    end

    context 'global fast executor' do

      specify 'reader creates a default pool when first called if none exists' do
        expect(Concurrent.global_fast_executor).not_to be_nil
        expect(Concurrent.global_fast_executor).to respond_to(:post)
      end
    end

    context 'global operation pool' do

      specify 'reader creates a default pool when first called if none exists' do
        expect(Concurrent.configuration.global_operation_pool).not_to be_nil
        expect(Concurrent.configuration.global_operation_pool).to respond_to(:post)
      end

      specify 'writer memoizes the given executor' do
        executor = ImmediateExecutor.new
        Concurrent.configure do |config|
          config.global_operation_pool = executor
        end
        expect(Concurrent.configuration.global_operation_pool).to eq executor
      end

      specify 'writer raises an exception if called after initialization' do
        executor = ImmediateExecutor.new
        Concurrent.configure do |config|
          config.global_operation_pool = executor
        end
        Concurrent.configuration.global_operation_pool
        expect {
          Concurrent.configure do |config|
            config.global_operation_pool = executor
          end
        }.to raise_error(ConfigurationError)
      end
    end
  end
end

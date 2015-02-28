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
      expect(Concurrent.global_timer_set).not_to be_nil
      expect(Concurrent.global_timer_set).to respond_to(:post)
    end

    context 'global fast executor' do

      specify 'reader creates a default pool when first called if none exists' do
        expect(Concurrent.global_fast_executor).not_to be_nil
        expect(Concurrent.global_fast_executor).to respond_to(:post)
      end
    end

    context 'global io executor' do

      specify 'reader creates a default pool when first called if none exists' do
        expect(Concurrent.global_io_executor).not_to be_nil
        expect(Concurrent.global_io_executor).to respond_to(:post)
      end
    end
  end
end

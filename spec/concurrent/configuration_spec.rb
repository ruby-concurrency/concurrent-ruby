require 'spec_helper'

module Concurrent

  describe Configuration do
    with_full_reset

    it 'creates a global timer pool' do
      Concurrent.configuration.global_timer_set.should_not be_nil
      Concurrent.configuration.global_timer_set.should respond_to(:post)
    end

    context 'global task pool' do

      specify 'reader creates a default pool when first called if none exists' do
        Concurrent.configuration.global_task_pool.should_not be_nil
        Concurrent.configuration.global_task_pool.should respond_to(:post)
      end

      specify 'writer memoizes the given executor' do
        executor = ImmediateExecutor.new
        Concurrent.configure do |config|
          config.global_task_pool = executor
        end
        Concurrent.configuration.global_task_pool.should eq executor
      end

      specify 'writer raises an exception if called after initialization' do
        executor = ImmediateExecutor.new
        Concurrent.configure do |config|
          config.global_task_pool = executor
        end
        Concurrent.configuration.global_task_pool
        expect {
          Concurrent.configure do |config|
            config.global_task_pool = executor
          end
        }.to raise_error(ConfigurationError)
      end
    end

    context 'global operation pool' do

      specify 'reader creates a default pool when first called if none exists' do
        Concurrent.configuration.global_operation_pool.should_not be_nil
        Concurrent.configuration.global_operation_pool.should respond_to(:post)
      end

      specify 'writer memoizes the given executor' do
        executor = ImmediateExecutor.new
        Concurrent.configure do |config|
          config.global_operation_pool = executor
        end
        Concurrent.configuration.global_operation_pool.should eq executor
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

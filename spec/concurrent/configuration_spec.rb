require 'spec_helper'

module Concurrent

  describe 'module functions' do

    context '#task' do
      pending
    end

    context '#operation' do
      pending
    end
  end

  describe OptionsParser do

    context 'get_executor_from' do
      pending
    end
  end

  describe Configuration do

    context 'configure' do

      it 'raises an exception if called twice'

      it 'raises an exception if called after tasks post to the thread pool'

      it 'raises an exception if called after operations post to the thread pool'

      it 'allows reconfiguration if set to :test mode'
    end

    context '#global_task_pool' do
      pending
    end

    context '#global_task_pool=' do
      pending
    end

    context '#global_operation_pool' do
      pending
    end

    context '#global_operation_pool=' do
      pending
    end

    context 'cores' do
      pending
    end

    context '#at_exit shutdown hook' do
      pending
    end
  end
end

require 'spec_helper'
require_relative 'thread_pool_shared'

module Concurrent

  describe SerializedExecutionDelegator do

    subject { SerializedExecutionDelegator.new(ImmediateExecutor.new) }

    it_should_behave_like :executor_service
  end
end

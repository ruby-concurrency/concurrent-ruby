require 'spec_helper'
require_relative 'thread_pool_shared'

module Concurrent

  describe ImmediateExecutor do

    subject { ImmediateExecutor.new }

    it_should_behave_like :executor_service
  end
end

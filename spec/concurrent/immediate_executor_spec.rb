require 'spec_helper'
require_relative 'global_thread_pool_shared'

module Concurrent

  describe ImmediateExecutor do

    subject { ImmediateExecutor.new }

    it_should_behave_like :global_thread_pool
  end
end

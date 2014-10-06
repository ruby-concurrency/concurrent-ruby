require 'spec_helper'
require_relative 'executor_service_shared'

module Concurrent

  describe IndirectImmediateExecutor do

    subject { IndirectImmediateExecutor.new }

    it_should_behave_like :executor_service
  end
end

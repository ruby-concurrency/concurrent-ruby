require 'spec_helper'

require_relative 'thread_pool_shared'

module Concurrent

  describe RubySingleThreadExecutor, :type=>:mrirbx do

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    subject { RubySingleThreadExecutor.new }

    it_should_behave_like :executor_service
  end
end

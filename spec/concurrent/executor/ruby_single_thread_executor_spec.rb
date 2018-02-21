require_relative 'executor_service_shared'

module Concurrent

  RSpec.describe RubySingleThreadExecutor, :type=>:mrirbx do

    after(:each) do
      subject.kill
      subject.wait_for_termination(0.1)
    end

    subject { RubySingleThreadExecutor.new }

    it_should_behave_like :executor_service
  end
end

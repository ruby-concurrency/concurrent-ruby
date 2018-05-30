require_relative 'executor_service_shared'

module Concurrent

  RSpec.describe RubySingleThreadExecutor, :type=>:mrirbx do

    after(:each) do
      subject.shutdown
      expect(subject.wait_for_termination(1)).to eq true
    end

    subject { RubySingleThreadExecutor.new }

    it_should_behave_like :executor_service
  end
end

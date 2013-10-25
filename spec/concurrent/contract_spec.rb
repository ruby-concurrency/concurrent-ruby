require 'spec_helper'
require_relative 'obligation_shared'

module Concurrent

  describe Contract do

    let!(:fulfilled_value) { 10 }
    let(:rejected_reason) { StandardError.new('Boom!') }

    let(:pending_subject) do
      @contract = Contract.new
      Thread.new do
        sleep(3)
        @contract.complete(fulfilled_value, nil)
      end
      @contract
    end

    let(:fulfilled_subject) do
      contract = Contract.new
      contract.complete(fulfilled_value, nil)
      contract
    end

    let(:rejected_subject) do
      contract = Contract.new
      contract.complete(nil, rejected_reason)
      contract
    end

    it_should_behave_like :obligation
  end
end

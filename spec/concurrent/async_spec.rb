require 'spec_helper'

module Concurrent

  describe Async do

    described_class do
      Class.new do
        include Concurrent::Async
        def echo(msg)
          sleep(rand)
          msg
        end
      end
    end

    context '#async' do
      pending
    end

    context '#await' do
      pending
    end
  end
end

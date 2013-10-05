require 'spec_helper'
require_relative 'runnable_shared'

module Concurrent

  describe Channel do

    subject { Channel.new }
    let(:runnable) { Channel }

    it_should_behave_like :runnable

  end
end

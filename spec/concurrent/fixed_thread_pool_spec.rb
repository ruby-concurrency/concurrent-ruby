require 'spec_helper'
require_relative 'fixed_thread_pool_shared'

module Concurrent

  describe FixedThreadPool do

    subject { described_class.new(5) }

    it_should_behave_like :fixed_thread_pool
  end
end

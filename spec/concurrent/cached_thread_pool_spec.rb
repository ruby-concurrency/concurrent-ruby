require 'spec_helper'
require_relative 'cached_thread_pool_shared'

module Concurrent

  describe CachedThreadPool do

    subject { described_class.new(5) }

    it_should_behave_like :cached_thread_pool
  end
end

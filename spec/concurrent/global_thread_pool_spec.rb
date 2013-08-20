require 'spec_helper'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe UsesGlobalThreadPool do

    let!(:thread_pool_user){ Class.new{ include UsesGlobalThreadPool } }
    it_should_behave_like Concurrent::UsesGlobalThreadPool
  end
end

require 'spec_helper'
require_relative 'thread_pool_shared'

share_examples_for :thread_pool_executor do

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :thread_pool
end

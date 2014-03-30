#require 'spec_helper'
#require_relative 'fixed_thread_pool_shared'
#
#module Concurrent
#
#  describe FixedThreadPool do
#
#    after(:each) do
#      subject.kill
#      sleep(0.1)
#    end
#
#    subject { described_class.new(5) }
#
#    it_should_behave_like :fixed_thread_pool
#  end
#end

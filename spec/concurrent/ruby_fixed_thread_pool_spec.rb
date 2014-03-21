require 'spec_helper'
require_relative 'fixed_thread_pool_shared'

module Concurrent

  describe RubyFixedThreadPool do

    subject { described_class.new(5) }

    it_should_behave_like :fixed_thread_pool

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        pool = described_class.new(5)
        pool.current_length.should eq 0
        5.times{ pool << proc{ sleep } }
        sleep(0.1)
        pool.current_length.should eq 5
        pool.kill
      end

      it 'never creates more than :num_threads threads' do
        pool = described_class.new(5)
        100.times{ pool << proc{ sleep } }
        sleep(0.1)
        pool.current_length.should eq 5
        pool.kill
      end
    end
  end
end

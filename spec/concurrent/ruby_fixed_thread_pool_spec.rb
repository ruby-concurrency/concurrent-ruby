require 'spec_helper'
require_relative 'fixed_thread_pool_shared'

module Concurrent

  describe RubyFixedThreadPool do

    subject { described_class.new(5) }

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :fixed_thread_pool

    context 'exception handling' do

      it 'restarts threads that experience exception' do
        count = subject.length
        count.times{ subject << proc{ raise StandardError } }
        sleep(1)
        subject.length.should eq count
      end
    end

    context 'worker creation and caching' do

      it 'creates new workers when there are none available' do
        pool = described_class.new(5)
        pool.current_length.should eq 0
        5.times{ pool << proc{ sleep(1) } }
        sleep(0.1)
        pool.current_length.should eq 5
        pool.kill
      end
    end
  end
end

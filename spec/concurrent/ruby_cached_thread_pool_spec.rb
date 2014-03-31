require 'spec_helper'
require_relative 'cached_thread_pool_shared'

module Concurrent

  describe RubyCachedThreadPool do

    subject { described_class.new(max_threads: 5, gc_interval: 0) }

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :cached_thread_pool

    context 'garbage collection' do

      subject{ described_class.new(idletime: 1, max_threads: 5, gc_interval: 0) }

      it 'removes from pool any thread that has been idle too long' do
        3.times { subject << proc{ sleep(0.1) } }
        sleep(0.1)
        subject.length.should eq 3
        sleep(2)
        subject << proc{ nil }
        sleep(0.1)
        subject.length.should < 3
      end

      it 'removes from pool any dead thread' do
        3.times { subject << proc{ sleep(0.1); raise Exception } }
        sleep(0.1)
        subject.length.should eq 3
        sleep(2)
        subject << proc{ nil }
        sleep(0.1)
        subject.length.should < 3
      end
    end

    context 'worker creation and caching' do

      subject{ described_class.new(idletime: 1, max_threads: 5) }

      it 'creates new workers when there are none available' do
        subject.length.should eq 0
        5.times{ sleep(0.1); subject << proc{ sleep(1) } }
        sleep(1)
        subject.length.should eq 5
      end

      it 'uses existing idle threads' do
        5.times{ subject << proc{ sleep(0.1) } }
        sleep(1)
        subject.length.should >= 5
        3.times{ subject << proc{ sleep(1) } }
        sleep(0.1)
        subject.length.should >= 5
      end
    end
  end
end

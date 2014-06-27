require 'spec_helper'
require_relative 'cached_thread_pool_shared'

module Concurrent

  describe RubyCachedThreadPool, :type=>:mrirbx do

    subject do
      described_class.new(
        overflow_policy: :discard,
        gc_interval: 0
      )
    end

    after(:each) do
      subject.kill
      sleep(0.1)
    end

    it_should_behave_like :cached_thread_pool

    context 'garbage collection' do

      subject{ described_class.new(idletime: 1, max_threads: 5, gc_interval: 0) }

      it 'removes from pool any thread that has been idle too long' do
        subject.instance_variable_set(:@idletime, 1)
        3.times { subject << proc{ sleep(0.1) } }
        sleep(0.1)
        expect(subject.length).to eq 3
        sleep(2)
        subject << proc{ nil }
        sleep(0.1)
        expect(subject.length).to be < 3
      end

      it 'removes from pool any dead thread' do
        3.times { subject << proc{ sleep(0.1); raise Exception } }
        sleep(0.1)
        expect(subject.length).to eq 3
        sleep(2)
        subject << proc{ nil }
        sleep(0.1)
        expect(subject.length).to be < 3
      end
    end

    context 'worker creation and caching' do

      subject{ described_class.new(idletime: 1, max_threads: 5) }

      it 'creates new workers when there are none available' do
        expect(subject.length).to eq 0
        5.times{ sleep(0.1); subject << proc{ sleep(1) } }
        sleep(1)
        expect(subject.length).to eq 5
      end

      it 'uses existing idle threads' do
        5.times{ subject << proc{ sleep(0.1) } }
        sleep(1)
        expect(subject.length).to be >= 5
        3.times{ subject << proc{ sleep(1) } }
        sleep(0.1)
        expect(subject.length).to be >= 5
      end
    end
  end
end

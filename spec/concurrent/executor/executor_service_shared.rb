require 'spec_helper'
require_relative 'global_thread_pool_shared'

share_examples_for :executor_service do

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :global_thread_pool

  context '#post' do

    it 'rejects the block while shutting down' do
      latch = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(1) }
      subject.shutdown
      subject.post{ latch.count_down }
      latch.wait(0.1).should be_false
    end

    it 'returns false while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.post{ nil }.should be_false
    end

    it 'rejects the block once shutdown' do
      subject.shutdown
      latch = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(1) }
      subject.post{ latch.count_down }
      latch.wait(0.1).should be_false
    end

    it 'returns false once shutdown' do
      subject.post{ nil }
      subject.shutdown
      sleep(0.1)
      subject.post{ nil }.should be_false
    end
  end

  context '#running?' do

    it 'returns true when the thread pool is running' do
      subject.should be_running
    end

    it 'returns false when the thread pool is shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.wait_for_termination(1)
      subject.should_not be_running
    end

    it 'returns false when the thread pool is shutdown' do
      subject.shutdown
      subject.wait_for_termination(1)
      subject.should_not be_running
    end

    it 'returns false when the thread pool is killed' do
      subject.kill
      subject.wait_for_termination(1)
      subject.should_not be_running
    end
  end

  context '#shutdown' do

    it 'stops accepting new tasks' do
      latch1 = Concurrent::CountDownLatch.new(1)
      latch2 = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(0.2); latch1.count_down }
      subject.shutdown
      subject.post{ latch2.count_down }.should be_false
      latch1.wait(1).should be_true
      latch2.wait(0.2).should be_false
    end

    it 'allows in-progress tasks to complete' do
      latch = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(0.1); latch.count_down }
      subject.shutdown
      latch.wait(1).should be_true
    end

    it 'allows pending tasks to complete' do
      latch = Concurrent::CountDownLatch.new(2)
      subject.post{ sleep(0.2); latch.count_down }
      subject.post{ sleep(0.2); latch.count_down }
      subject.shutdown
      latch.wait(1).should be_true
    end
  end

  context '#shutdown followed by #wait_for_termination' do

    it 'allows in-progress tasks to complete' do
      latch = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(0.1); latch.count_down }
      subject.shutdown
      subject.wait_for_termination(1)
      latch.wait(1).should be_true
    end

    it 'allows pending tasks to complete' do
      q = Queue.new
      5.times do |i|
        subject.post { sleep 0.1; q << i }
      end
      subject.shutdown
      subject.wait_for_termination(1)
      q.length.should eq 5
    end

    it 'stops accepting/running new tasks' do
      expected = Concurrent::AtomicFixnum.new(0)
      subject.post{ sleep(0.1); expected.increment }
      subject.post{ sleep(0.1); expected.increment }
      subject.shutdown
      subject.post{ expected.increment }
      subject.wait_for_termination(1)
      expected.value.should == 2
    end
  end

  context '#kill' do

    it 'stops accepting new tasks' do
      expected = Concurrent::AtomicBoolean.new(false)
      latch = Concurrent::CountDownLatch.new(1)
      subject.post{ sleep(0.1); latch.count_down }
      latch.wait(1)
      subject.kill
      subject.post{ expected.make_true }.should be_false
      sleep(0.1)
      expected.value.should be_false
    end

    it 'rejects all pending tasks' do
      subject.post{ sleep(1) }
      sleep(0.1)
      subject.kill
      sleep(0.1)
      subject.post{ nil }.should be_false
    end
  end

  context '#wait_for_termination' do

    it 'immediately returns true when no operations are pending' do
      subject.shutdown
      subject.wait_for_termination(0).should be_true
    end

    it 'returns true after shutdown has complete' do
      10.times { subject << proc{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1).should be_true
    end

    it 'returns true when shutdown sucessfully completes before timeout' do
      subject.post{ sleep(0.5) }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1).should be_true
    end

    it 'returns false when shutdown fails to complete before timeout' do
      unless subject.is_a?(Concurrent::SerialExecutor)
        100.times{ subject.post{ sleep(1) } }
        sleep(0.1)
        subject.shutdown
        subject.wait_for_termination(0).should be_false
      end
    end
  end
end

require 'spec_helper'
require_relative 'global_thread_pool_shared'
require 'thread'

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
      subject.post{ sleep(1) }
      sleep(0.1)
      subject.shutdown
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
    end

    it 'allows in-progress tasks to complete' do
      @expected = false
      subject.post{ @expected = true }
      sleep(0.1)
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end

    it 'allows pending tasks to complete' do
      @expected = false
      subject.post{ sleep(0.2) }
      subject.post{ sleep(0.2); @expected = true }
      sleep(0.1)
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end
  end

  context '#shutdown followed by #wait_for_termination' do
    it "allows in-progress tasks to complete" do
      @expected = false
      subject.post{ sleep 0.1; @expected = true }
      subject.shutdown
      subject.wait_for_termination(1)
      @expected.should be_true
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

    it "stops accepting/running new tasks" do
      @expected = :start
      subject.post{ sleep(0.1) }
      subject.post{ sleep(0.1); @expected = :should_be_run }
      subject.shutdown
      subject.post{ @expected = :should_not_be_run }
      subject.wait_for_termination(1)
      @expected.should == :should_be_run
    end
  end


  context '#kill' do

    it 'stops accepting new tasks' do
      subject.post{ sleep(1) }
      sleep(0.1)
      subject.kill
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
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
      100.times{ subject.post{ sleep(1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(0).should be_false
    end
  end
end

share_examples_for :thread_pool do

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  it_should_behave_like :executor_service

  context '#length' do

    it 'returns zero on creation' do
      subject.length.should eq 0
    end

    it 'returns zero once shut down' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.length.should eq 0
    end

    it 'aliased as #current_length' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.current_length.should eq subject.length
    end
  end

  context '#scheduled_task_count' do

    it 'returns zero on creation' do
      subject.scheduled_task_count.should eq 0
    end

    it 'returns the approximate number of tasks that have been post thus far' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.scheduled_task_count.should > 0
    end

    it 'returns the approximate number of tasks that were post' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.scheduled_task_count.should > 0
    end
  end

  context '#completed_task_count' do

    it 'returns zero on creation' do
      subject.completed_task_count.should eq 0
    end

    it 'returns the approximate number of tasks that have been completed thus far' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.completed_task_count.should > 0
    end

    it 'returns the approximate number of tasks that were completed' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      subject.completed_task_count.should > 0
    end
  end

  context '#shutdown' do

    it 'allows threads to exit normally' do
      10.times{ subject << proc{ nil } }
      subject.length.should > 0
      sleep(0.1)
      subject.shutdown
      sleep(1)
      subject.length.should == 0
    end
  end
end

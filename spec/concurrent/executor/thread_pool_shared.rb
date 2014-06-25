require 'spec_helper'
require_relative 'executor_service_shared'

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

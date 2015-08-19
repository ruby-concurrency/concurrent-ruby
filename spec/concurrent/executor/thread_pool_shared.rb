require_relative 'executor_service_shared'

shared_examples :thread_pool do

  after(:each) do
    subject.kill
    subject.wait_for_termination(0.1)
  end

  it_should_behave_like :executor_service

  context '#auto_terminate?' do

    it 'returns true by default' do
      expect(subject.auto_terminate?).to be true
    end

    it 'returns true when :enable_at_exit_handler is true' do
      if described_class.to_s =~ /FixedThreadPool$/
        subject = described_class.new(1, auto_terminate: true)
      else
        subject = described_class.new(auto_terminate: true)
      end
      expect(subject.auto_terminate?).to be true
    end

    it 'returns false when :enable_at_exit_handler is false' do
      if described_class.to_s =~ /FixedThreadPool$/
        subject = described_class.new(1, auto_terminate: false)
      else
        subject = described_class.new(auto_terminate: false)
      end
      expect(subject.auto_terminate?).to be false
    end
  end

  context '#length' do

    it 'returns zero on creation' do
      expect(subject.length).to eq 0
    end

    it 'returns zero once shut down' do
      5.times{ subject.post{ sleep(0.1) } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.length).to eq 0
    end
  end

  context '#scheduled_task_count' do

    it 'returns zero on creation' do
      expect(subject.scheduled_task_count).to eq 0
    end

    it 'returns the approximate number of tasks that have been post thus far' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.scheduled_task_count).to be > 0
    end

    it 'returns the approximate number of tasks that were post' do
      10.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.scheduled_task_count).to be > 0
    end
  end

  context '#completed_task_count' do

    it 'returns zero on creation' do
      expect(subject.completed_task_count).to eq 0
    end

    it 'returns the approximate number of tasks that have been completed thus far' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      expect(subject.completed_task_count).to be > 0
    end

    it 'returns the approximate number of tasks that were completed' do
      5.times{ subject.post{ raise StandardError } }
      5.times{ subject.post{ nil } }
      sleep(0.1)
      subject.shutdown
      subject.wait_for_termination(1)
      expect(subject.completed_task_count).to be > 0
    end
  end

  context '#shutdown' do

    it 'allows threads to exit normally' do
      10.times{ subject << proc{ nil } }
      expect(subject.length).to be > 0
      sleep(0.1)
      subject.shutdown
      sleep(1)
      expect(subject.length).to eq(0)
    end
  end
end

require 'spec_helper'

share_examples_for :stoppable do

  after(:each) do
    subject.stop
  end

  context 'stopping' do

    it 'raises an exception when #before_stop does not receive a block' do
      expect {
        subject.before_stop
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception if #before_stop is called more than once' do
      subject.before_stop{ nil }
      expect {
        subject.before_stop{ nil }
      }.to raise_error(Concurrent::Runnable::LifecycleError)
    end

    it 'returns self from #before_stop' do
      task = subject
      task.before_stop{ nil }.should eq task
    end

    it 'calls the #before_stop block when stopping' do
      @expected = false
      subject.before_stop{ @expected = true }
      subject.stop
      sleep(0.1)
      @expected.should be_true
    end
  end
end

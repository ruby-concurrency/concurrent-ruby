require 'spec_helper'

share_examples_for :stoppable do

  after(:each) do
    subject.stop
  end

  context 'stopping' do

    it 'raises an exception when #at_stop does not receive a block' do
      expect {
        subject.at_stop
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception if #at_stop is called more than once' do
      subject.at_stop{ nil }
      expect {
        subject.at_stop{ nil }
      }.to raise_error(Concurrent::Runnable::LifecycleError)
    end

    it 'returns self from #at_stop' do
      task = subject
      task.at_stop{ nil }.should eq task
    end

    it 'calls the #at_stop block when stopping' do
      @expected = false
      subject.at_stop{ @expected = true }
      subject.stop
      sleep(0.1)
      @expected.should be_true
    end
  end
end

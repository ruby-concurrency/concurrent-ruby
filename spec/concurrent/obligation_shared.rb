require 'spec_helper'

module Concurrent

  share_examples_for Obligation do

    context '#state' do

      it 'is :pending when first created' do
        f = pending_subject
        f.state.should == :pending
        f.should be_pending
      end

      it 'is :fulfilled when the handler completes' do
        f = fulfilled_subject
        f.state.should == :fulfilled
        f.should be_fulfilled
      end

      it 'is :rejected when the handler raises an exception' do
        f = rejected_subject
        f.state.should == :rejected
        f.should be_rejected
      end
    end

    context '#value' do

      it 'blocks the caller when :pending and timeout is nil' do
        f = pending_subject
        sleep(0.1)
        f.value.should be_true
        f.should be_fulfilled
      end

      it 'returns nil when reaching the optional timeout value' do
        f = pending_subject
        sleep(0.1)
        f.value(0).should be_nil
        f.should be_pending
      end

      it 'returns immediately when timeout is zero' do
        Timeout.should_not_receive(:timeout).with(any_args())
        f = pending_subject
        sleep(0.1)
        f.value(0).should be_nil
        f.should be_pending
      end

      it 'is nil when :pending' do
        expected = pending_subject.value(0)
        expected.should be_nil
      end

      it 'is nil when :rejected' do
        expected = rejected_subject.value
        expected.should be_nil
      end

      it 'is set to the return value of the block when :fulfilled' do
        expected = fulfilled_subject.value
        expected.should eq fulfilled_value
      end
    end

    context '#reason' do

      it 'is nil when :pending' do
        pending_subject.reason.should be_nil
      end

      it 'is nil when :fulfilled' do
        fulfilled_subject.reason.should be_nil
      end

      it 'is set to error object of the exception when :rejected' do
        rejected_subject.reason.should be_a(Exception)
        rejected_subject.reason.to_s.should =~ /#{rejected_reason}/
      end
    end

    context 'Kernel aliases' do

      it 'aliases Kernel#deref for #deref' do
        deref(fulfilled_subject).should eq fulfilled_value
        deref(fulfilled_subject, 0).should eq fulfilled_value
      end

      it 'aliases Kernel#pending? for #pending?' do
        #NOTE: was structured like others but was incorrectly failing
        # on fulfilled_subject
        fulfilled_subject.should_receive(:pending?).once
        pending?(fulfilled_subject)
        pending_subject.should_receive(:pending?).once
        pending?(pending_subject)
        rejected_subject.should_receive(:pending?).once
        pending?(rejected_subject)
      end

      it 'aliases Kernel#fulfilled? for #fulfilled?' do
        fulfilled?(fulfilled_subject).should be_true
        fulfilled?(pending_subject).should be_false
        fulfilled?(rejected_subject).should be_false
      end

      it 'aliases Kernel#realized? for #realized?' do
        realized?(fulfilled_subject).should be_true
        realized?(pending_subject).should be_false
        realized?(rejected_subject).should be_false
      end

      it 'aliases Kernel#rejected? for #rejected?' do
        rejected?(rejected_subject).should be_true
        rejected?(fulfilled_subject).should be_false
        rejected?(pending_subject).should be_false
      end
    end
  end
end

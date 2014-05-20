require 'spec_helper'

module Concurrent

  describe Obligation do

    let (:obligation_class) do

      Class.new do
        include Obligation

        def initialize
          init_mutex
        end

        public :state=, :compare_and_set_state, :if_state, :mutex
        attr_writer :value, :reason
      end
    end

    let (:obligation) { obligation_class.new }
    let (:event) { double 'event' }

    share_examples_for :incomplete do
      it 'should be not completed' do
        obligation.should_not be_completed
      end

      it 'should be incomplete' do
        obligation.should be_incomplete
      end

      methods = [:value, :value!, :no_error!]
      methods.each do |method|
        describe "##{method}" do

          it 'should return immediately if timeout is zero' do
            obligation.send(method, 0).should(method == :no_error! ? eq(obligation) : be_nil)
          end

          it 'should block on the event if timeout is not set' do
            obligation.stub(:event).and_return(event)
            event.should_receive(:wait).with(nil)

            obligation.send method
          end

          it 'should block on the event if timeout is not zero' do
            obligation.stub(:event).and_return(event)
            event.should_receive(:wait).with(5)

            obligation.send(method, 5)
          end

        end
      end
    end

    context 'unscheduled' do
      before(:each) { obligation.state = :unscheduled }
      it_should_behave_like :incomplete
    end

    context 'pending' do
      before(:each) { obligation.state = :pending }
      it_should_behave_like :incomplete
    end

    context 'fulfilled' do

      before(:each) do
        obligation.state = :fulfilled
        obligation.send(:value=, 42)
        obligation.stub(:event).and_return(event)
      end

      it 'should be completed' do
        obligation.should be_completed
      end

      it 'should be not incomplete' do
        obligation.should_not be_incomplete
      end

      describe '#value' do

        it 'should return immediately if timeout is zero' do
          obligation.value(0).should eq 42
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          obligation.value.should eq 42
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          obligation.value(5).should eq 42
        end

      end

      describe '#value!' do

        it 'should return immediately if timeout is zero' do
          obligation.value!(0).should eq 42
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          obligation.value!.should eq 42
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          obligation.value!(5).should eq 42
        end

      end

      describe '#no_error!' do

        it 'should return immediately if timeout is zero' do
          obligation.no_error!(0).should eq obligation
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          obligation.no_error!.should eq obligation
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          obligation.no_error!(5).should eq obligation
        end

      end

    end

    context 'rejected' do

      before(:each) do
        obligation.state = :rejected
        obligation.stub(:event).and_return(event)
      end

      it 'should be completed' do
        obligation.should be_completed
      end

      it 'should be not incomplete' do
        obligation.should_not be_incomplete
      end


      describe '#value' do

        it 'should return immediately if timeout is zero' do
          event.should_not_receive(:wait)

          obligation.value(0).should be_nil
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          obligation.value.should be_nil
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          obligation.value(5).should be_nil
        end

      end

      describe '#value!' do

        it 'should return immediately if timeout is zero' do
          event.should_not_receive(:wait)

          -> { obligation.value!(0) }.should raise_error
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          -> { obligation.value! }.should raise_error
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          -> { obligation.value!(5) }.should raise_error
        end

      end

      describe '#no_error!' do

        it 'should return immediately if timeout is zero' do
          event.should_not_receive(:wait)

          -> { obligation.no_error!(0) }.should raise_error
        end

        it 'should return immediately if timeout is not set' do
          event.should_not_receive(:wait)

          -> { obligation.no_error! }.should raise_error
        end

        it 'should return immediately if timeout is not zero' do
          event.should_not_receive(:wait)

          -> { obligation.no_error!(5) }.should raise_error
        end

      end

    end

    describe '#compare_and_set_state' do

      before(:each) { obligation.state = :unscheduled }

      context 'unexpected state' do
        it 'should return false if state is not the expected one' do
          obligation.compare_and_set_state(:pending, :rejected).should be_false
        end

        it 'should not change the state if current is not the expected one' do
          obligation.compare_and_set_state(:pending, :rejected)
          obligation.state.should eq :unscheduled
        end
      end

      context 'expected state' do
        it 'should return true if state is the expected one' do
          obligation.compare_and_set_state(:pending, :unscheduled).should be_true
        end

        it 'should not change the state if current is not the expected one' do
          obligation.compare_and_set_state(:pending, :unscheduled)
          obligation.state.should eq :pending
        end
      end

    end

    describe '#if_state' do

      before(:each) { obligation.state = :unscheduled }

      it 'should raise without block' do
        expect { obligation.if_state(:pending) }.to raise_error(ArgumentError)
      end

      it 'should return false if state is not expected' do
        obligation.if_state(:pending, :rejected) { 42 }.should be_false
      end

      it 'should the block value if state is expected' do
        obligation.if_state(:rejected, :unscheduled) { 42 }.should eq 42
      end

      it 'should execute the block within the mutex' do
        obligation.if_state(:unscheduled) { obligation.mutex.should be_locked }
      end

    end

  end
end

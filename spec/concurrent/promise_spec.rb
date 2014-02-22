require 'spec_helper'
require_relative 'obligation_shared'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe Promise do

    let!(:thread_pool_user){ Promise }
    it_should_behave_like Concurrent::UsesGlobalThreadPool

    let!(:fulfilled_value) { 10 }
    let!(:rejected_reason) { StandardError.new('mojo jojo') }

    let(:pending_subject) do
      Promise.new{ sleep(0.3); fulfilled_value }.execute
    end

    let(:fulfilled_subject) do
      Promise.new{ fulfilled_value }.execute.tap{ sleep(0.1) }
    end

    let(:rejected_subject) do
      Promise.new{ raise rejected_reason }.
        rescue{ nil }.execute.tap(){ sleep(0.1) }
    end

    before(:each) do
      Promise.thread_pool = FixedThreadPool.new(1)
    end

    it_should_behave_like :obligation

    it 'includes Dereferenceable' do
      promise = Promise.new{ nil }
      promise.should be_a(Dereferenceable)
    end

    context '#after creation' do
      it 'should be unscheduled' do
        p = Promise.new { nil }
        p.should be_unscheduled
      end
    end

    context '#execute' do

      context 'unscheduled' do

        it 'sets the promise to :pending' do
          p = Promise.new { sleep(0.1) }.execute
          p.should be_pending
        end

        it 'posts the block given in construction' do
          Promise.thread_pool.should_receive(:post).with(any_args)
          Promise.new { nil }.execute
        end

      end

      context 'pending' do

        it 'sets the promise to :pending' do
          p = pending_subject.execute
          p.should be_pending
        end

        it 'does not posts again' do
          Promise.thread_pool.should_receive(:post).with(any_args).once
          pending_subject.execute
        end

      end


      describe 'with children' do

        let(:root) { Promise.new { sleep(0.1); nil } }
        let(:c1) { root.then { nil } }
        let(:c2) { root.then { nil } }
        let(:c2_1) { c2.then { nil } }

        before(:each) do
          #fixme: brittle test: without this line children will be not initialized
          [root, c1, c2, c2_1].each { |p| p.should be_unscheduled }
        end

        context 'when called on the root' do
          it 'should set all promises to :pending' do
            root.execute

            c1.should be_pending
            c2.should be_pending
            c2_1.should be_pending
            [root, c1, c2, c2_1].each { |p| p.should be_pending }
          end
        end

        context 'when called on a child' do
          it 'should set all promises to :pending' do
            c2_1.execute

            [root, c1, c2, c2_1].each { |p| p.should be_pending }
          end
        end

      end
    end



    context 'class #execute' do

      it 'creates a new Promise' do
        p = Promise.execute{ nil }
        p.should be_a(Promise)
      end

      it 'passes the block to the new Promise' do
        @expected = false
        Promise.execute { @expected = true }
        sleep(0.1)
        @expected.should be_true
      end

      it 'calls #execute on the new Promise' do
        p = double('promise')
        Promise.stub(:new).with(any_args).and_return(p)
        p.should_receive(:execute).with(no_args)
        Promise.execute{ nil }
      end
    end

    context '#then' do

      it 'returns a new Promise when :unscheduled' do
        p1 = Promise.new { nil }
        p2 = p1.then{}
        p2.should be_a(Promise)
        p1.should_not eq p2
        end

      it 'returns a new Promise when :pending' do
        p1 = pending_subject
        p2 = p1.then{}
        p2.should be_a(Promise)
        p1.should_not eq p2
      end

      it 'returns a new Promise when :fulfilled' do
        p1 = fulfilled_subject
        p2 = p1.then{}
        p2.should be_a(Promise)
        p1.should_not eq p2
      end

      it 'returns a new Promise when :rejected' do
        p1 = rejected_subject
        p2 = p1.then{}
        p2.should be_a(Promise)
        p1.should_not eq p2
      end

      it 'immediately rejects new promises when self has been rejected' do
        p = rejected_subject
        p.then.should be_rejected
      end

      it 'accepts a nil block' do
        lambda {
          pending_subject.then
        }.should_not raise_error
      end

      it 'can be called more than once' do
        p = pending_subject
        p1 = p.then{}
        p2 = p.then{}
        p1.object_id.should_not eq p2.object_id
      end
    end

    context '#rescue' do

      it 'returns self when a block is given' do
        p1 = pending_subject
        p2 = p1.rescue{}
        p1.object_id.should eq p2.object_id
      end

      it 'returns self when no block is given' do
        p1 = pending_subject
        p2 = p1.rescue
        p1.object_id.should eq p2.object_id
      end

      it 'accepts an exception class as the first parameter' do
        lambda {
          pending_subject.rescue(StandardError){}
        }.should_not raise_error
      end
    end

    context 'fulfillment' do

      it 'passes all arguments to the first promise in the chain' do
        expected = nil
        Promise.new(1, 2, 3) { |a, b, c| expected = [a, b, c] }.execute
        sleep(0.1)
        expected.should eq [1, 2, 3]
      end

      it 'passes the result of each block to all its children' do
        expected = nil
        Promise.new(10){|a| a * 2 }.then{|result| expected = result}.execute
        sleep(0.1)
        expected.should eq 20
      end

      it 'sets the promise value to the result if its block' do
        p = Promise.new(10){|a| a * 2 }.then{|result| result * 2}.execute
        sleep(0.1)
        p.value.should eq 40
      end

      it 'sets the promise state to :fulfilled if the block completes' do
        p = Promise.new(10){|a| a * 2 }.then{|result| result * 2}.execute
        sleep(0.1)
        p.should be_fulfilled
      end

      it 'passes the last result through when a promise has no block' do
        expected = nil
        Promise.new(10){|a| a * 2 }.then.then{|result| expected = result}.execute
        sleep(0.1)
        expected.should eq 20
      end
    end

    context 'rejection' do

      it 'sets the promise reason the error object on exception' do
        p = Promise.new{ raise StandardError.new('Boom!') }.execute
        sleep(0.1)
        p.reason.should be_a(StandardError)
        p.reason.should.to_s =~ /Boom!/
      end

      it 'sets the promise state to :rejected on exception' do
        p = Promise.new{ raise StandardError.new('Boom!') }.execute
        sleep(0.1)
        p.should be_rejected
      end

      it 'recursively rejects all children' do
        root = Promise.new{ raise StandardError.new('Boom!') }
        promises = 10.times.collect{ root.then{ true } }
        root.execute
        sleep(0.5)
        promises.each{|p| p.should be_rejected }
      end

      it 'skips processing rejected promises' do
        root = Promise.new{ raise StandardError.new('Boom!') }
        promises = 3.times.collect{ root.then{ true } }
        root.execute
        sleep(0.5)
        promises.each{|p| p.value.should_not be_true }
      end

      it 'calls the first exception block with a matching class' do
        @expected = nil
        Promise.new{ raise StandardError }.
          rescue(StandardError){|ex| @expected = 1 }.
          rescue(StandardError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }.execute
        sleep(0.1)
        @expected.should eq 1
      end

      it 'matches all with a rescue with no class given' do
        @expected = nil
        Promise.new{ raise NoMethodError }.
          rescue(LoadError){|ex| @expected = 1 }.
          rescue{|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }.execute
        sleep(0.1)
        @expected.should eq 2
      end

      it 'searches associated rescue handlers in order' do
        Promise.thread_pool = CachedThreadPool.new

        @expected = nil
        Promise.new{ raise ArgumentError }.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }.execute
        sleep(0.1)
        @expected.should eq 1

        @expected = nil
        Promise.new{ raise LoadError }.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }.execute
        sleep(0.1)
        @expected.should eq 2

        @expected = nil
        Promise.new{ raise StandardError }.
          rescue(ArgumentError){|ex| @expected = 1 }.
          rescue(LoadError){|ex| @expected = 2 }.
          rescue(StandardError){|ex| @expected = 3 }.execute
        sleep(0.1)
        @expected.should eq 3
      end

      it 'passes the exception object to the matched block' do
        @expected = nil
        Promise.new{ raise StandardError }.
          rescue(ArgumentError){|ex| @expected = ex }.
          rescue(LoadError){|ex| @expected = ex }.
          rescue(StandardError){|ex| @expected = ex }.execute
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'ignores rescuers without a block' do
        @expected = nil
        Promise.new{ raise StandardError }.
          rescue(StandardError).
          rescue(StandardError){|ex| @expected = ex }.execute
        sleep(0.1)
        @expected.should be_a(StandardError)
      end

      it 'supresses the exception if no rescue matches' do
        lambda {
          Promise.new{ raise StandardError }.
            rescue(ArgumentError){|ex| @expected = ex }.
            rescue(NotImplementedError){|ex| @expected = ex }.
            rescue(NoMethodError){|ex| @expected = ex }.execute
          sleep(0.1)
        }.should_not raise_error
      end

      it 'supresses exceptions thrown from rescue handlers' do
        lambda {
          Promise.new{ raise ArgumentError }.
          rescue(StandardError){ raise StandardError }.execute
          sleep(0.1)
        }.should_not raise_error
      end

      it 'calls matching rescue handlers on all children' do
        latch = CountDownLatch.new(5)
        @expected = []
        Promise.new{ sleep(0.1); raise StandardError }.
          then{ sleep(0.1) }.rescue{ latch.count_down }.
          then{ sleep(0.1) }.rescue{ latch.count_down }.
          then{ sleep(0.1) }.rescue{ latch.count_down }.
          then{ sleep(0.1) }.rescue{ latch.count_down }.
          then{ sleep(0.1) }.rescue{ latch.count_down }.execute

        latch.wait(1).should be_true
        latch.count.should eq 0

      end

      it 'matches a rescue handler added after rejection' do
        @expected = false
        p = Promise.new{ aise StandardError }.execute
        sleep(0.1)
        p.rescue(StandardError){ @expected = true }
        @expected.should be_true
      end
    end

    context 'aliases' do

      it 'aliases #realized? for #fulfilled?' do
        fulfilled_subject.should be_realized
      end

      it 'aliases #deref for #value' do
        fulfilled_subject.deref.should eq fulfilled_value
      end

      it 'aliases #catch for #rescue' do
        @expected = nil
        Promise.new{ raise StandardError }.catch{ @expected = true }.execute
        sleep(0.1)
        @expected.should be_true
      end

      it 'aliases #on_error for #rescue' do
        @expected = nil
        Promise.new{ raise StandardError }.on_error{ @expected = true }.execute
        sleep(0.1)
        @expected.should be_true
      end
    end
  end
end

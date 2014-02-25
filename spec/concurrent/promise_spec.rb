require 'spec_helper'
require_relative 'obligation_shared'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe Promise do

    let!(:thread_pool_user){ Promise }
    it_should_behave_like Concurrent::UsesGlobalThreadPool

    let(:empty_root) { Promise.new { nil } }
    let!(:fulfilled_value) { 10 }
    let!(:rejected_reason) { StandardError.new('mojo jojo') }

    let(:pending_subject) do
      Promise.new{ sleep(0.3); fulfilled_value }.execute
    end

    let(:fulfilled_subject) do
      Promise.fulfil(fulfilled_value)
    end

    let(:rejected_subject) do
      Promise.reject( rejected_reason )
    end

    before(:each) do
      Promise.thread_pool = FixedThreadPool.new(1)
    end

    it_should_behave_like :obligation

    it 'includes Dereferenceable' do
      promise = Promise.new{ nil }
      promise.should be_a(Dereferenceable)
    end

    context 'initializers' do
      describe '.fulfil' do

        subject { Promise.fulfil(10) }

        it 'should return a Promise' do
          subject.should be_a Promise
        end

        it 'should return a fulfilled Promise' do
          subject.should be_fulfilled
        end

        it 'should return a Promise with set value' do
          subject.value.should eq 10
        end
      end

      describe '.reject' do

        let(:reason) { ArgumentError.new }
        subject { Promise.reject(reason) }

        it 'should return a Promise' do
          subject.should be_a Promise
        end

        it 'should return a rejected Promise' do
          subject.should be_rejected
        end

        it 'should return a Promise with set reason' do
          subject.reason.should be reason
        end
      end

      describe '.new' do
        it 'should return an unscheduled Promise' do
          p = Promise.new { nil }
          p.should be_unscheduled
        end
      end

      describe '.execute' do
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

    describe '#then' do

      it 'returns a new promise when a block is passed' do
        child = empty_root.then { nil }
        child.should be_a Promise
        child.should_not be empty_root
      end

      it 'returns a new promise when a rescuer is passed' do
        child = empty_root.then(Proc.new{})
        child.should be_a Promise
        child.should_not be empty_root
      end

      it 'returns a new promise when a block and rescuer are passed' do
        child = empty_root.then(Proc.new{}) { nil }
        child.should be_a Promise
        child.should_not be empty_root
      end

      it 'should have block or rescuers' do
        expect { empty_root.then }.to raise_error(ArgumentError)
      end

      context 'unscheduled' do

        let(:p1) { Promise.new {nil} }
        let(:child) { p1.then{} }

        it 'returns a new promise' do
          child.should be_a Promise
          p1.should_not be child
        end

        it 'returns an unscheduled promise' do
          child.should be_unscheduled
        end
      end

      context 'pending' do

        let(:child) { pending_subject.then{} }

        it 'returns a new promise' do
          child.should be_a Promise
          pending_subject.should_not be child
        end

        it 'returns a pending promise' do
          child.should be_pending
        end
      end

      context 'fulfilled' do
        it 'returns a new Promise' do
          p1 = fulfilled_subject
          p2 = p1.then{}
          p2.should be_a(Promise)
          p1.should_not eq p2
        end
      end

      context 'rejected' do
        it 'returns a new Promise when :rejected' do
          p1 = rejected_subject
          p2 = p1.then{}
          p2.should be_a(Promise)
          p1.should_not eq p2
        end

        it 'immediately rejects new promises' do
          p = rejected_subject
          p.then {}.should be_rejected
        end
      end

      it 'can be called more than once' do
        p = pending_subject
        p1 = p.then{}
        p2 = p.then{}
        p1.should_not be p2
      end
    end

    describe 'on_success' do
      it 'should have a block' do
        expect { empty_root.on_success }.to raise_error(ArgumentError)
      end

      it 'returns a new promise' do
        child = empty_root.on_success { nil }
        child.should be_a Promise
        child.should_not be empty_root
      end
    end

    context '#rescue' do

      it 'returns a new promise' do
        child = empty_root.rescue(Proc.new{ nil })
        child.should be_a Promise
        child.should_not be empty_root
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
        Promise.new(10){ |a| a * 2 }.then{ |result| expected = result}.execute
        sleep(0.1)
        expected.should eq 20
      end

      it 'sets the promise value to the result if its block' do
        root = Promise.new(10) { |a| a * 2 }
        p = root.then{ |result| result * 2}.execute
        sleep(0.1)
        root.value.should eq 20
        p.value.should eq 40
      end

      it 'sets the promise state to :fulfilled if the block completes' do
        p = Promise.new(10){|a| a * 2 }.then{|result| result * 2}.execute
        sleep(0.1)
        p.should be_fulfilled
      end

      it 'passes the last result through when a promise has no block' do
        expected = nil
        Promise.new(10){|a| a * 2 }.then(Proc.new{}).then{|result| expected = result}.execute
        sleep(0.1)
        expected.should eq 20
      end

      it 'can manage long chain' do
        root = Promise.new(10) { |a| a * 2}
        p1 = root.then { |b| b * 3 }
        p2 = root.then { |c| c + 2 }
        p3 = p1.then { |d| d + 7 }

        root.execute
        sleep(0.1)

        root.value.should eq 20
        p1.value.should eq 60
        p2.value.should eq 22
        p3.value.should eq 67
      end
    end

    context 'rejection' do

      before(:each) { pending }

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
        p = Promise.new{ raise StandardError }.execute
        sleep(0.1)
        p.rescue(StandardError){ @expected = true }
        @expected.should be_true
      end
    end

    context 'aliases' do

      before(:each) { pending }

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

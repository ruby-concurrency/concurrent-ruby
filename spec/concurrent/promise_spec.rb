require 'spec_helper'
require_relative 'obligation_shared'

module Concurrent

  describe Promise do

    let(:executor) { PerThreadExecutor.new }

    let(:empty_root) { Promise.new(executor: executor){ nil } }
    let!(:fulfilled_value) { 10 }
    let!(:rejected_reason) { StandardError.new('mojo jojo') }

    let(:pending_subject) do
      Promise.new(executor: executor){ sleep(0.3); fulfilled_value }.execute
    end

    let(:fulfilled_subject) do
      Promise.fulfill(fulfilled_value, executor: executor)
    end

    let(:rejected_subject) do
      Promise.reject(rejected_reason, executor: executor)
    end

    it_should_behave_like :obligation

    it 'includes Dereferenceable' do
      promise = Promise.new{ nil }
      expect(promise).to be_a(Dereferenceable)
    end

    context 'initializers' do
      describe '.fulfill' do

        subject { Promise.fulfill(10) }

        it 'should return a Promise' do
          expect(subject).to be_a Promise
        end

        it 'should return a fulfilled Promise' do
          expect(subject).to be_fulfilled
        end

        it 'should return a Promise with set value' do
          expect(subject.value).to eq 10
        end
      end

      describe '.reject' do

        let(:reason) { ArgumentError.new }
        subject { Promise.reject(reason) }

        it 'should return a Promise' do
          expect(subject).to be_a Promise
        end

        it 'should return a rejected Promise' do
          expect(subject).to be_rejected
        end

        it 'should return a Promise with set reason' do
          expect(subject.reason).to be reason
        end
      end

      describe '.new' do
        it 'should return an unscheduled Promise' do
          p = Promise.new(executor: executor){ nil }
          expect(p).to be_unscheduled
        end
      end

      describe '.execute' do
        it 'creates a new Promise' do
          p = Promise.execute(executor: executor){ nil }
          expect(p).to be_a(Promise)
        end

        it 'passes the block to the new Promise' do
          p = Promise.execute(executor: executor){ 20 }
          sleep(0.1)
          expect(p.value).to eq 20
        end

        it 'calls #execute on the new Promise' do
          p = double('promise')
          allow(Promise).to receive(:new).with({executor: executor}).and_return(p)
          expect(p).to receive(:execute).with(no_args)
          Promise.execute(executor: executor){ nil }
        end
      end
    end

    context '#execute' do

      context 'unscheduled' do

        it 'sets the promise to :pending' do
          p = Promise.new(executor: executor){ sleep(0.1) }.execute
          expect(p).to be_pending
        end

        it 'posts the block given in construction' do
          expect(executor).to receive(:post).with(any_args)
          Promise.new(executor: executor){ nil }.execute
        end
      end

      context 'pending' do

        it 'sets the promise to :pending' do
          p = pending_subject.execute
          expect(p).to be_pending
        end

        it 'does not posts again' do
          expect(executor).to receive(:post).with(any_args).once
          pending_subject.execute
        end
      end

      describe 'with children' do

        let(:root) { Promise.new(executor: executor){ sleep(0.1); nil } }
        let(:c1) { root.then { sleep(0.1); nil } }
        let(:c2) { root.then { sleep(0.1); nil } }
        let(:c2_1) { c2.then { sleep(0.1); nil } }

        context 'when called on the root' do
          it 'should set all promises to :pending' do
            root.execute

            expect(c1).to be_pending
            expect(c2).to be_pending
            expect(c2_1).to be_pending
            [root, c1, c2, c2_1].each { |p| expect(p).to be_pending }
          end
        end

        context 'when called on a child' do
          it 'should set all promises to :pending' do
            c2_1.execute

            [root, c1, c2, c2_1].each { |p| expect(p).to be_pending }
          end
        end
      end
    end

    describe '#then' do

      it 'returns a new promise when a block is passed' do
        child = empty_root.then { nil }
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end

      it 'returns a new promise when a rescuer is passed' do
        child = empty_root.then(Proc.new{})
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end

      it 'returns a new promise when a block and rescuer are passed' do
        child = empty_root.then(Proc.new{}) { nil }
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end

      it 'should have block or rescuers' do
        expect { empty_root.then }.to raise_error(ArgumentError)
      end

      context 'unscheduled' do

        let(:p1) { Promise.new(executor: executor){nil} }
        let(:child) { p1.then{} }

        it 'returns a new promise' do
          expect(child).to be_a Promise
          expect(p1).not_to be child
        end

        it 'returns an unscheduled promise' do
          expect(child).to be_unscheduled
        end
      end

      context 'pending' do

        let(:child) { pending_subject.then{} }

        it 'returns a new promise' do
          expect(child).to be_a Promise
          expect(pending_subject).not_to be child
        end

        it 'returns a pending promise' do
          expect(child).to be_pending
        end
      end

      context 'fulfilled' do
        it 'returns a new Promise' do
          p1 = fulfilled_subject
          p2 = p1.then{}
          expect(p2).to be_a(Promise)
          expect(p1).not_to eq p2
        end

        it 'notifies fulfillment to new child' do
          child = fulfilled_subject.then(Proc.new{ 7 }) { |v| v + 5 }
          expect(child.value).to eq fulfilled_value + 5
        end
      end

      context 'rejected' do
        it 'returns a new Promise when :rejected' do
          p1 = rejected_subject
          p2 = p1.then{}
          expect(p2).to be_a(Promise)
          expect(p1).not_to eq p2
        end

        it 'notifies rejection to new child' do
          child = rejected_subject.then(Proc.new{ 7 }) { |v| v + 5 }
          expect(child.value).to eq 7
        end
      end

      it 'can be called more than once' do
        p = pending_subject
        p1 = p.then{}
        p2 = p.then{}
        expect(p1).not_to be p2
      end
    end

    describe 'on_success' do
      it 'should have a block' do
        expect { empty_root.on_success }.to raise_error(ArgumentError)
      end

      it 'returns a new promise' do
        child = empty_root.on_success { nil }
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end
    end

    context '#rescue' do

      it 'returns a new promise' do
        child = empty_root.rescue { nil }
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end
    end

    describe '#flat_map' do

      it 'returns a promise' do
        child = empty_root.flat_map { nil }
        expect(child).to be_a Promise
        expect(child).not_to be empty_root
      end

      it 'succeeds if both promises succeed' do
        child = Promise.new(executor: executor) { 1 }.
          flat_map { |v| Promise.new(executor: executor) { v + 10 } }.execute.wait

        expect(child.value!).to eq(11)
      end

      it 'fails if the left promise fails' do
        child = Promise.new(executor: executor) { fail }.
          flat_map { |v| Promise.new(executor: executor) { v + 10 } }.execute.wait

        expect(child).to be_rejected
      end

      it 'fails if the right promise fails' do
        child = Promise.new(executor: executor) { 1 }.
          flat_map { |v| Promise.new(executor: executor) { fail } }.execute.wait

        expect(child).to be_rejected
      end

      it 'fails if the generating block fails' do
        child = Promise.new(executor: executor) { }.flat_map { fail }.execute.wait

        expect(child).to be_rejected
      end

    end

    describe '#zip' do
      let(:promise1) { Promise.new(executor: executor) { 1 } }
      let(:promise2) { Promise.new(executor: executor) { 2 } }
      let(:promise3) { Promise.new(executor: executor) { [3] } }

      it 'yields the results as an array' do
        composite = promise1.zip(promise2, promise3).execute.wait

        expect(composite.value).to eq([1, 2, [3]])
      end

      it 'fails if one component fails' do
        composite = promise1.zip(promise2, rejected_subject, promise3).execute.wait

        expect(composite).to be_rejected
      end
    end

    describe '.zip' do
      let(:promise1) { Promise.new(executor: executor) { 1 } }
      let(:promise2) { Promise.new(executor: executor) { 2 } }
      let(:promise3) { Promise.new(executor: executor) { [3] } }

      it 'yields the results as an array' do
        composite = Promise.zip(promise1, promise2, promise3).execute.wait

        expect(composite.value).to eq([1, 2, [3]])
      end

      it 'fails if one component fails' do
        composite = Promise.zip(promise1, promise2, rejected_subject, promise3).execute.wait

        expect(composite).to be_rejected
      end
    end

    context 'fulfillment' do

      it 'passes the result of each block to all its children' do
        expected = nil
        Promise.new(executor: executor){ 20 }.then{ |result| expected = result }.execute
        sleep(0.1)
        expect(expected).to eq 20
      end

      it 'sets the promise value to the result if its block' do
        root = Promise.new(executor: executor){ 20 }
        p = root.then{ |result| result * 2}.execute
        sleep(0.1)
        expect(root.value).to eq 20
        expect(p.value).to eq 40
      end

      it 'sets the promise state to :fulfilled if the block completes' do
        p = Promise.new(executor: executor){ 10 * 2 }.then{|result| result * 2}.execute
        sleep(0.1)
        expect(p).to be_fulfilled
      end

      it 'passes the last result through when a promise has no block' do
        expected = nil
        Promise.new(executor: executor){ 20 }.then(Proc.new{}).then{|result| expected = result}.execute
        sleep(0.1)
        expect(expected).to eq 20
      end

      it 'uses result as fulfillment value when a promise has no block' do
        p = Promise.new(executor: executor){ 20 }.then(Proc.new{}).execute
        sleep(0.1)
        expect(p.value).to eq 20
      end

      it 'can manage long chain' do
        root = Promise.new(executor: executor){ 20 }
        p1 = root.then { |b| b * 3 }
        p2 = root.then { |c| c + 2 }
        p3 = p1.then { |d| d + 7 }

        root.execute
        sleep(0.1)

        expect(root.value).to eq 20
        expect(p1.value).to eq 60
        expect(p2.value).to eq 22
        expect(p3.value).to eq 67
      end
    end

    context 'rejection' do

      it 'passes the reason to all its children' do
        expected = nil
        Promise.new(executor: executor){ raise ArgumentError }.then(Proc.new{ |reason| expected = reason }).execute
        sleep(0.1)
        expect(expected).to be_a ArgumentError
      end

      it 'sets the promise value to the result if its block' do
        root = Promise.new(executor: executor){ raise ArgumentError }
        p = root.then(Proc.new{ |reason| 42 }).execute
        sleep(0.1)
        expect(p.value).to eq 42
      end

      it 'sets the promise state to :rejected if the block completes' do
        p = Promise.new(executor: executor){ raise ArgumentError }.execute
        sleep(0.1)
        expect(p).to be_rejected
      end

      it 'uses reason as rejection reason when a promise has no rescue callable' do
        p = Promise.new(executor: ImmediateExecutor.new){ raise ArgumentError }.then{ |val| val }.execute
        sleep(0.1)
        expect(p).to be_rejected
        expect(p.reason).to be_a ArgumentError
      end

    end

    context 'aliases' do

      it 'aliases #realized? for #fulfilled?' do
        expect(fulfilled_subject).to be_realized
      end

      it 'aliases #deref for #value' do
        expect(fulfilled_subject.deref).to eq fulfilled_value
      end

      it 'aliases #catch for #rescue' do
        child = rejected_subject.catch { 7 }
        expect(child.value).to eq 7
      end

      it 'aliases #on_error for #rescue' do
        child = rejected_subject.on_error { 7 }
        expect(child.value).to eq 7
      end
    end
  end
end

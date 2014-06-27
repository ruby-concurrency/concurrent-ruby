require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'
require_relative 'observable_shared'

module Concurrent

  describe IVar do

    let!(:value) { 10 }

    subject do
      i = IVar.new
      i.set(14)
      i
    end

    context 'behavior' do

      # obligation

      let!(:fulfilled_value) { 10 }
      let(:rejected_reason) { StandardError.new('Boom!') }

      let(:pending_subject) do
        @i = IVar.new
        Thread.new do
          sleep(3)
          @i.set(fulfilled_value)
        end
        @i
      end

      let(:fulfilled_subject) do
        i = IVar.new
        i.set(fulfilled_value)
        i
      end

      let(:rejected_subject) do
        i = IVar.new
        i.fail(rejected_reason)
        i
      end

      it_should_behave_like :obligation

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        IVar.new(value, opts)
      end

      def dereferenceable_observable(opts = {})
        IVar.new(IVar::NO_VALUE, opts)
      end

      def execute_dereferenceable(subject)
        subject.set('value')
      end

      it_should_behave_like :dereferenceable

      # observable
      
      subject{ IVar.new }
      
      def trigger_observable(observable)
        observable.set('value')
      end

      it_should_behave_like :observable
    end

    context '#initialize' do

      it 'does not have to set an initial value' do
        i = IVar.new
        expect(i).to be_incomplete
      end

      it 'does not set an initial value if you pass NO_VALUE' do
        i = IVar.new(IVar::NO_VALUE)
        expect(i).to be_incomplete
      end

      it 'can set an initial value' do
        i = IVar.new(14)
        expect(i).to be_completed
      end

    end

    context '#set' do

      it 'sets the state to be fulfilled' do
        i = IVar.new
        i.set(14)
        expect(i).to be_fulfilled
      end

      it 'sets the value' do
        i = IVar.new
        i.set(14)
        expect(i.value).to eq 14
      end

      it 'raises an exception if set more than once' do
        i = IVar.new
        i.set(14)
        expect {i.set(2)}.to raise_error(Concurrent::MultipleAssignmentError)
        expect(i.value).to eq 14
      end

      it 'returns self' do
        i = IVar.new
        expect(i.set(42)).to eq i
      end
    end

    context '#fail' do

      it 'sets the state to be rejected' do
        i = IVar.new
        i.fail
        expect(i).to be_rejected
      end

      it 'sets the value to be nil' do
        i = IVar.new
        i.fail
        expect(i.value).to be_nil
      end

      it 'raises an exception if set more than once' do
        i = IVar.new
        i.fail
        expect {i.fail}.to raise_error(Concurrent::MultipleAssignmentError)
        expect(i.value).to be_nil
      end

      it 'defaults the reason to a StandardError' do
        i = IVar.new
        i.fail
        expect(i.reason).to be_a StandardError
      end

      it 'returns self' do
        i = IVar.new
        expect(i.fail).to eq i
      end
    end

    context 'observation' do

      let(:clazz) do
        Class.new do
          attr_reader :value
          attr_reader :reason
          attr_reader :count
          define_method(:update) do |time, value, reason|
            @count = @count.to_i + 1
            @value = value
            @reason = reason
          end
        end
      end

      let(:observer) { clazz.new }

      it 'notifies all observers on #set' do
        i = IVar.new
        i.add_observer(observer)

        i.set(42)

        expect(observer.value).to eq(42)
        expect(observer.reason).to be_nil
      end

      context 'deadlock avoidance' do

        def reentrant_observer(i)
          obs = Object.new
          obs.define_singleton_method(:update) do |time, value, reason|
            @value = i.value
          end
          obs.define_singleton_method(:value) { @value }
          obs
        end

        it 'should notify observers outside mutex lock' do
          i = IVar.new
          obs = reentrant_observer(i)

          i.add_observer(obs)
          i.set(42)

          expect(obs.value).to eq 42
        end

        it 'should notify a new observer added after fulfillment outside lock' do
          i = IVar.new
          i.set(42)
          obs = reentrant_observer(i)

          i.add_observer(obs)

          expect(obs.value).to eq 42
        end
      end

    end
  end
end

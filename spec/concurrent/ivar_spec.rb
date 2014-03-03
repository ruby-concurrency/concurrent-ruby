require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'
require_relative 'uses_global_thread_pool_shared'

module Concurrent

  describe IVar do

    let!(:value) { 10 }
    
    subject do
      i = IVar.new{ value }
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
        @i.complete(fulfilled_value, nil)
      end
      @i
    end

    let(:fulfilled_subject) do
      i = IVar.new
      i.complete(fulfilled_value, nil)
      i
    end

    let(:rejected_subject) do
      i = IVar.new
      i.complete(nil, rejected_reason)
      i
    end

    it_should_behave_like :obligation

      # dereferenceable

      def dereferenceable_subject(value, opts = {})
        i = IVar.new(opts)
        i.set(value)
        i
      end

      it_should_behave_like :dereferenceable
    end

    context '#set' do

      it 'sets the value' do
        i = IVar.new
        i.set(14)
        i.value.should eq 14
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

        observer.value.should == 42
        observer.reason.should be_nil
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

          obs.value.should eq 42
        end

        it 'should notify a new observer added after fulfillment outside lock' do
          i = IVar.new
          i.set(42)
          obs = reentrant_observer(i)

          i.add_observer(obs)

          obs.value.should eq 42
        end
      end

    end
  end
end

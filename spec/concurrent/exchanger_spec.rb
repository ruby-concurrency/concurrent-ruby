require 'spec_helper'

module Concurrent

  describe Exchanger do

    subject { Exchanger.new }
    let!(:exchanger) { subject } # let is not thread safe, let! creates the object before ensuring uniqueness

    describe 'exchange' do
      context 'without timeout' do
        it 'should block' do
          t = Thread.new { exchanger.exchange(1) }
          sleep(0.1)
          t.status.should eq 'sleep'
        end

        it 'should receive the other value' do
          first_value = nil
          second_value = nil

          Thread.new { first_value = exchanger.exchange(2) }
          Thread.new { second_value = exchanger.exchange(4) }

          sleep(0.1)

          first_value.should eq 4
          second_value.should eq 2
        end

        it 'can be reused' do
          first_value = nil
          second_value = nil

          Thread.new { first_value = exchanger.exchange(1) }
          Thread.new { second_value = exchanger.exchange(0) }

          sleep(0.1)

          Thread.new { first_value = exchanger.exchange(10) }
          Thread.new { second_value = exchanger.exchange(12) }

          sleep(0.1)

          first_value.should eq 12
          second_value.should eq 10
        end
      end

      context 'with timeout' do

        it 'should block until timeout' do
          start = Time.now.to_f
          exchanger.exchange(2, 0.1).should be_nil
          (Time.now.to_f - start).should be_within(0.05).of(0.1)
        end
      end
    end
  end
end

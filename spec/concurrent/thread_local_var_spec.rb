require 'spec_helper'

module Concurrent

  describe Future do

    context '#initialize' do

      it 'can set an initial value' do
        v = ThreadLocalVar.new(14)
        v.value.should eq 14
      end

      it 'sets nil as a default initial value' do
        v = ThreadLocalVar.new
        v.value.should be_nil
      end

      it 'sets the same initial value for all threads' do
        v = ThreadLocalVar.new(14)
        t1 = Thread.new { v.value }
        t2 = Thread.new { v.value }
        t1.value.should eq 14
        t2.value.should eq 14
      end

    end

    context '#value' do

      it 'returns the current value' do
        v = ThreadLocalVar.new(14)
        v.value.should eq 14
      end

      it 'returns the value after modification' do
        v = ThreadLocalVar.new(14)
        v.value = 2
        v.value.should eq 2
      end

    end

    context '#value=' do

      it 'sets a new value' do
        v = ThreadLocalVar.new(14)
        v.value = 2
        v.value.should eq 2
      end

      it 'returns the new value' do
        v = ThreadLocalVar.new(14)
        (v.value = 2).should eq 2
      end

      it 'does not modify the initial value for other threads' do
        v = ThreadLocalVar.new(14)
        v.value = 2
        t = Thread.new { v.value }
        t.value.should eq 14
      end

      it 'does not modify the value for other threads' do
        v = ThreadLocalVar.new(14)
        v.value = 2

        b1 = CountDownLatch.new(2)
        b2 = CountDownLatch.new(2)

        t1 = Thread.new do
          b1.count_down
          b1.wait
          v.value = 1
          b2.count_down
          b2.wait
          v.value
        end
        
        t2 = Thread.new do
          b1.count_down
          b1.wait
          v.value = 2
          b2.count_down
          b2.wait
          v.value
        end
        
        t1.value.should eq 1
        t2.value.should eq 2
      end

    end

  end

end

require 'spec_helper'

module Concurrent

  describe TVar do

    context '#initialize' do

      it 'accepts an initial value' do
        t = TVar.new(14)
        t.value.should eq 14
      end

    end

    context '#value' do

      it 'gets the value' do
        t = TVar.new(14)
        t.value.should eq 14
      end

    end

    context '#value=' do

      it 'sets the value' do
        t = TVar.new(14)
        t.value = 2
        t.value.should eq 2
      end

    end

  end

  describe '#atomically' do

    it 'raises an exception when no block given' do
      expect { Concurrent::atomically }.to raise_error(ArgumentError)
    end

    it 'retries on abort' do
      count = 0

      Concurrent::atomically do
        if count == 0
          count = 1
          Concurrent::abort_transaction
        else
          count = 2
        end
      end

      count.should eq 2
    end

    it 'commits writes if the transaction succeeds' do
      t = TVar.new(0)

      Concurrent::atomically do
        t.value = 1
      end

      t.value.should eq 1
    end

    it 'undoes writes if the transaction is aborted' do
      t = TVar.new(0)

      count = 0

      Concurrent::atomically do
        if count == 0
          t.value = 1
          count = 1
          Concurrent::abort_transaction
        end
      end

      t.value.should eq 0
    end

    it 'provides atomicity' do
      t1 = TVar.new(0)
      t2 = TVar.new(0)

      count = 0

      Concurrent::atomically do
        if count == 0
          count = 1
          t1.value = 1
          Concurrent::abort_transaction
          t2.value = 2
        end
      end

      t1.value.should eq 0
      t2.value.should eq 0
    end

    it 'provides isolation' do
      t = TVar.new(0)

      Thread.new do
        Concurrent::atomically do
          t1.value = 1
          sleep(1)
        end
      end

      sleep(0.5)

      t.value.should eq 0
    end

    it 'nests' do
      Concurrent::atomically do
        Concurrent::atomically do
          Concurrent::atomically do
          end
        end
      end
    end

  end

  describe '#abort_transaction' do

    it 'raises an exception outside an #atomically block' do
      expect { Concurrent::abort_transaction }.to raise_error(Concurrent::AbortError)
    end

  end

end

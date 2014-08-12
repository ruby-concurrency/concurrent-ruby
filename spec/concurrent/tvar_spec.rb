require 'spec_helper'

module Concurrent

  describe TVar do

    context '#initialize' do

      it 'accepts an initial value' do
        t = TVar.new(14)
        expect(t.value).to eq 14
      end

    end

    context '#value' do

      it 'gets the value' do
        t = TVar.new(14)
        expect(t.value).to eq 14
      end

    end

    context '#value=' do

      it 'sets the value' do
        t = TVar.new(14)
        t.value = 2
        expect(t.value).to eq 2
      end

    end

  end

  describe '#atomically' do

    it 'raises an exception when no block given' do
      expect { Concurrent::atomically }.to raise_error(ArgumentError)
    end

    it 'raises the same exception that was raised in Concurrent::atomically' do
      expect {
        Concurrent::atomically do
          raise StandardError, 'This is an error!'
        end
      }.to raise_error(StandardError, 'This is an error!')
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

      expect(count).to eq 2
    end

    it 'commits writes if the transaction succeeds' do
      t = TVar.new(0)

      Concurrent::atomically do
        t.value = 1
      end

      expect(t.value).to eq 1
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

      expect(t.value).to eq 0
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

      expect(t1.value).to eq 0
      expect(t2.value).to eq 0
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

      expect(t.value).to eq 0
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
      expect { Concurrent::abort_transaction }.to raise_error(Concurrent::Transaction::AbortError)
    end

  end

end

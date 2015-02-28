module Concurrent

  describe Lazy do

    context '#initialize' do

      it 'raises an exception when no block given' do
        expect {
          Lazy.new
        }.to raise_error(ArgumentError)
      end
    end

    context '#value' do

      let(:task){ proc{ nil } }

      it 'does not call the block before #value is called' do
        expect(task).to_not receive(:call).with(any_args)
        Lazy.new(&task)
      end

      it 'calls the block when #value is called' do
        expect(task).to receive(:call).once.with(any_args).and_return(nil)
        Lazy.new(&task).value
      end

      it 'only calls the block once no matter how often #value is called' do
        expect(task).to receive(:call).once.with(any_args).and_return(nil)
        lazy = Lazy.new(&task)
        5.times{ lazy.value }
      end

      it 'does not lock the mutex once the block has been called' do
        mutex = Mutex.new
        allow(Mutex).to receive(:new).and_return(mutex)

        lazy = Lazy.new(&task)
        lazy.value

        expect(mutex).to_not receive(:synchronize).with(any_args)
        expect(mutex).to_not receive(:lock).with(any_args)
        expect(mutex).to_not receive(:try_lock).with(any_args)

        5.times{ lazy.value }
      end

      context 'on exception' do

        it 'suppresses the error' do
          expect {
            Lazy.new{ raise StandardError }
          }.to_not raise_exception
        end

        it 'sets the value to nil when no default is given' do
          lazy = Lazy.new{ raise StandardError }
          expect(lazy.value).to be_nil
        end

        it 'sets the value appropriately when given a default' do
          lazy = Lazy.new(100){ raise StandardError }
          expect(lazy.value).to eq 100
        end

        it 'does not try to call the block again' do
          mutex = Mutex.new
          allow(Mutex).to receive(:new).and_return(mutex)

          lazy = Lazy.new{ raise StandardError }
          lazy.value

          expect(mutex).to_not receive(:synchronize).with(any_args)
          expect(mutex).to_not receive(:lock).with(any_args)
          expect(mutex).to_not receive(:try_lock).with(any_args)

          5.times{ lazy.value }
        end
      end
    end
  end
end

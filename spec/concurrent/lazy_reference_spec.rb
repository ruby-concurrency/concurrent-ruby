module Concurrent

  describe LazyReference do

    context '#initialize' do

      it 'raises an exception when no block given' do
        expect {
          LazyReference.new
        }.to raise_error(ArgumentError)
      end
    end

    context '#value' do

      let(:task){ proc{ nil } }

      it 'does not call the block before #value is called' do
        expect(task).to_not receive(:call).with(any_args)
        LazyReference.new(&task)
      end

      it 'calls the block when #value is called' do
        expect(task).to receive(:call).once.with(any_args).and_return(nil)
        LazyReference.new(&task).value
      end

      it 'only calls the block once no matter how often #value is called' do
        expect(task).to receive(:call).once.with(any_args).and_return(nil)
        lazy = LazyReference.new(&task)
        5.times{ lazy.value }
      end

      context 'on exception' do

        it 'suppresses the error' do
          expect {
            LazyReference.new{ raise StandardError }
          }.to_not raise_exception
        end

        it 'sets the value to nil when no default is given' do
          lazy = LazyReference.new{ raise StandardError }
          expect(lazy.value).to be_nil
        end

        it 'sets the value appropriately when given a default' do
          lazy = LazyReference.new(100){ raise StandardError }
          expect(lazy.value).to eq 100
        end
      end
    end
  end
end

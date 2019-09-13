require 'rbconfig'

module Concurrent

  require 'concurrent/atomic/constant_thread_local_var'

  RSpec.describe ConstantThreadLocalVar do

    context "#value" do
      it 'can return default value' do
        v = described_class.new("apple")
        expect(v.value).to eq("apple")

        v = described_class.new do
          "orange"
        end
        expect(v.value).to eq("orange")
      end
    end

    context "#value=" do
      it 'can set value to same value' do
        v = described_class.new("apple")
        v.value = "apple"
      end

      it 'will raise an ArgumentError when attempting to change immutable value' do
        v = described_class.new do
          "apple"
        end

        expect do
          v.value = "orange"
        end.to raise_error(ArgumentError)
      end
    end

    context '#bind' do
      it 'will raise when attempting to bind to a different value' do
        v = described_class.new("apple")
        expect do
          v.bind("orange") {}
        end.to raise_error(ArgumentError)
      end

      it 'works when bind value is the same' do

        v = described_class.new("apple")
        v.bind("apple") do
          expect(v.value).to eq("apple")
        end
      end
    end
  end

end

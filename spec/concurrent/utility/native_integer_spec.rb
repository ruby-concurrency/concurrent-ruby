require 'rbconfig/sizeof'
require 'concurrent/utility/native_integer'
require 'concurrent/thread_safe/util'
require 'concurrent/atomic/atomic_fixnum'

# Regression for #1057: `Integer#size` reports the C `long` byte width, which
# is 4 on 64-bit Windows (LLP64) even though pointers are 8 bytes there, so
# every `0.size`-derived width constant used to be wrong on that platform.
# These specs assert literal values (not the bounds formula itself), so a
# reversion to `0.size`-derived bounds fails visibly on Win64 CI instead of
# passing self-referentially.
module Concurrent

  RSpec.describe Utility::NativeInteger do
    if RbConfig::SIZEOF['void*'] == 8
      it 'derives a 62-bit signed bound from an 8-byte pointer width' do
        expect(Utility::NativeInteger::MAX_VALUE).to eq 4611686018427387903
        expect(Utility::NativeInteger::MIN_VALUE).to eq(-4611686018427387904)
      end
    elsif RbConfig::SIZEOF['void*'] == 4
      it 'derives a 30-bit signed bound from a 4-byte pointer width' do
        expect(Utility::NativeInteger::MAX_VALUE).to eq 1073741823
        expect(Utility::NativeInteger::MIN_VALUE).to eq(-1073741824)
      end
    end
  end

  RSpec.describe MutexAtomicFixnum do
    # Consumer-level regression: on Win64 the old `0.size`-derived bound
    # (~1.07e9) rejected valid values well within a real Fixnum's range.
    if RbConfig::SIZEOF['void*'] == 8
      it 'accepts a value beyond the old 32-bit-derived bound' do
        expect { described_class.new(2**31) }.not_to raise_error
      end
    end

    it 'accepts Utility::NativeInteger::MAX_VALUE' do
      expect { described_class.new(Utility::NativeInteger::MAX_VALUE) }.not_to raise_error
    end

    it 'raises RangeError one past Utility::NativeInteger::MAX_VALUE' do
      expect { described_class.new(Utility::NativeInteger::MAX_VALUE + 1) }.to raise_error(RangeError)
    end
  end

  module ThreadSafe
    module Util
      RSpec.describe 'ThreadSafe::Util::FIXNUM_BIT_SIZE' do
        if RbConfig::SIZEOF['void*'] == 8
          it 'is 62 on an 8-byte pointer width' do
            expect(FIXNUM_BIT_SIZE).to eq 62
          end
        end
      end
    end
  end
end

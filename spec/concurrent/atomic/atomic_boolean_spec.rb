require 'spec_helper'

shared_examples :atomic_boolean do

  describe 'construction' do

    it 'sets the initial value' do
      expect(described_class.new(true).value).to be_truthy
    end

    it 'defaults the initial value to false' do
      expect(described_class.new.value).to be_falsey
    end

    it 'evaluates the truthiness of a true value' do
      expect(described_class.new(10).value).to be_truthy
    end

    it 'evaluates the truthiness of a false value' do
      expect(described_class.new(nil).value).to be_falsey
    end
  end

  describe '#value' do

    it 'returns the current value' do
      counter = described_class.new(true)
      expect(counter.value).to be_truthy
      counter.make_false
      expect(counter.value).to be_falsey
      counter.make_true
      expect(counter.value).to be_truthy
    end
  end

  describe '#value=' do

    it 'sets the #value to the given `Boolean`' do
      atomic = described_class.new(true)
      atomic.value = false
      expect(atomic.value).to be_falsey
    end

    it 'returns the new value' do
      atomic = described_class.new(false)
      expect(atomic.value = true).to be_truthy
    end

    it 'evaluates the truthiness of a true value' do
      atomic = described_class.new(false)
      atomic.value = 10
      expect(atomic.value).to be_truthy
    end

    it 'evaluates the truthiness of a false value' do
      atomic = described_class.new(true)
      atomic.value = nil
      expect(atomic.value).to be_falsey
    end
  end

  describe '#true?' do

    specify { expect(described_class.new(true).true?).to be_truthy }

    specify { expect(described_class.new(false).true?).to be_falsey }
  end

  describe '#false?' do

    specify { expect(described_class.new(true).false?).to be_falsey }

    specify { expect(described_class.new(false).false?).to be_truthy }
  end

  describe '#make_true' do

    it 'makes a false value true and returns true' do
      subject = described_class.new(false)
      expect(subject.make_true).to be_truthy
      expect(subject.value).to be_truthy
    end

    it 'keeps a true value true and returns false' do
      subject = described_class.new(true)
      expect(subject.make_true).to be_falsey
      expect(subject.value).to be_truthy
    end
  end

  describe '#make_false' do

    it 'makes a true value false and returns true' do
      subject = described_class.new(true)
      expect(subject.make_false).to be_truthy
      expect(subject.value).to be_falsey
    end

    it 'keeps a false value false and returns false' do
      subject = described_class.new(false)
      expect(subject.make_false).to be_falsey
      expect(subject.value).to be_falsey
    end
  end
end

module Concurrent

  describe MutexAtomicBoolean do

    it_should_behave_like :atomic_boolean

    specify 'construction is synchronized' do
      mutex = double('mutex')
      expect(Mutex).to receive(:new).once.with(no_args).and_return(mutex)
      described_class.new
    end

    context 'instance methods' do

      before(:each) do
        mutex = double('mutex')
        allow(Mutex).to receive(:new).with(no_args).and_return(mutex)
        expect(mutex).to receive(:lock)
        expect(mutex).to receive(:unlock)
      end

      specify 'value is synchronized' do
        described_class.new.value
      end

      specify 'value= is synchronized' do
        described_class.new.value = 10
      end

      specify 'true? is synchronized' do
        described_class.new.true?
      end

      specify 'false? is synchronized' do
        described_class.new.false?
      end

      specify 'make_true is synchronized' do
        described_class.new.make_true
      end

      specify 'make_false is synchronized' do
        described_class.new.make_false
      end
    end
  end

  if TestHelpers.jruby?

    describe JavaAtomicBoolean do
      it_should_behave_like :atomic_boolean
    end
  end

  describe AtomicBoolean do
    if jruby?
      it 'inherits from JavaAtomicBoolean' do
        expect(AtomicBoolean.ancestors).to include(JavaAtomicBoolean)
      end
    else
      it 'inherits from MutexAtomicBoolean' do
        expect(AtomicBoolean.ancestors).to include(MutexAtomicBoolean)
      end
    end
  end
end

require 'spec_helper'

share_examples_for :atomic_boolean do

  describe 'construction' do

    it 'sets the initial value' do
      described_class.new(true).value.should be_true
    end

    it 'defaults the initial value to false' do
      described_class.new.value.should be_false
    end

    it 'evaluates the truthiness of a true value' do
      described_class.new(10).value.should be_true
    end

    it 'evaluates the truthiness of a false value' do
      described_class.new(nil).value.should be_false
    end
  end

  describe '#value' do

    it 'returns the current value' do
      counter = described_class.new(true)
      counter.value.should be_true
      counter.make_false
      counter.value.should be_false
      counter.make_true
      counter.value.should be_true
    end
  end

  describe '#value=' do

    it 'sets the #value to the given `Boolean`' do
      atomic = described_class.new(true)
      atomic.value = false
      atomic.value.should be_false
    end

    it 'returns the new value' do
      atomic = described_class.new(false)
      (atomic.value = true).should be_true
    end

    it 'evaluates the truthiness of a true value' do
      atomic = described_class.new(false)
      atomic.value = 10
      atomic.value.should be_true
    end

    it 'evaluates the truthiness of a false value' do
      atomic = described_class.new(true)
      atomic.value = nil
      atomic.value.should be_false
    end
  end

  describe '#true?' do

    specify { described_class.new(true).true?.should be_true }

    specify { described_class.new(false).true?.should be_false }
  end

  describe '#false?' do

    specify { described_class.new(true).false?.should be_false }

    specify { described_class.new(false).false?.should be_true }
  end

  describe '#make_true' do

    it 'makes a false value true and returns true' do
      subject = described_class.new(false)
      subject.make_true.should be_true
      subject.value.should be_true
    end

    it 'keeps a true value true and returns false' do
      subject = described_class.new(true)
      subject.make_true.should be_false
      subject.value.should be_true
    end
  end

  describe '#make_false' do

    it 'makes a true value false and returns true' do
      subject = described_class.new(true)
      subject.make_false.should be_true
      subject.value.should be_false
    end

    it 'keeps a false value false and returns false' do
      subject = described_class.new(false)
      subject.make_false.should be_false
      subject.value.should be_false
    end
  end
end

module Concurrent

  describe MutexAtomicBoolean do

    it_should_behave_like :atomic_boolean

    specify 'construction is synchronized' do
      mutex = double('mutex')
      Mutex.should_receive(:new).once.with(no_args).and_return(mutex)
      described_class.new
    end

    context 'instance methods' do

      before(:each) do
        mutex = double('mutex')
        Mutex.stub(:new).with(no_args).and_return(mutex)
        mutex.should_receive(:lock)
        mutex.should_receive(:unlock)
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

  if jruby?

    describe JavaAtomicBoolean do
      it_should_behave_like :atomic_boolean
    end
  end

  describe AtomicBoolean do
    if jruby?
      it 'inherits from JavaAtomicBoolean' do
        AtomicBoolean.ancestors.should include(JavaAtomicBoolean)
      end
    else
      it 'inherits from MutexAtomicBoolean' do
        AtomicBoolean.ancestors.should include(MutexAtomicBoolean)
      end
    end
  end
end

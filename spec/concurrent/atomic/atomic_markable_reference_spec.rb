shared_examples :atomic_markable_reference do
  # use a number outside JRuby's fixnum cache range, to ensure identity is
  # preserved
  let(:atomic) { Concurrent::Edge::AtomicMarkableReference.new 1000, true }

  specify :test_construct do
    expect(atomic.value).to eq 1000
    expect(atomic.marked?).to eq true
  end

  specify :test_set do
    val, mark = atomic.set(1001, true)

    expect(atomic.value).to eq 1001
    expect(atomic.marked?).to eq true

    expect(val).to eq 1001
    expect(mark).to eq true
  end

  specify :test_update do
    val, mark = atomic.update { |v, m| [v + 1, !m] }

    expect(atomic.value).to eq 1001
    expect(atomic.marked?).to eq false

    expect(val).to eq 1001
    expect(mark).to eq false
  end

  specify :test_try_update do
    val, mark = atomic.try_update { |v, m| [v + 1, !m] }

    expect(atomic.value).to eq 1001

    expect(val).to eq 1001
    expect(mark).to eq false
  end

  specify :test_try_update_fails do
    expect do
      # assigning within block exploits implementation detail for test
      atomic.try_update do |v, m|
        atomic.set(1001, false)
        [v + 1, !m]
      end
    end.to raise_error Concurrent::ConcurrentUpdateError
  end

  specify :test_update_retries do
    tries = 0

    # assigning within block exploits implementation detail for test
    atomic.update do |v, m|
      tries += 1
      atomic.set(1001, false)
      [v + 1, !m]
    end

    expect(tries).to eq 2
  end

  specify :test_numeric_cas do
    # non-idempotent Float (JRuby, Rubinius, MRI < 2.0.0 or 32-bit)
    atomic.set(1.0 + 0.1, true)
    expect(atomic.compare_and_set(1.0 + 0.1, 1.2, true, false))
      .to be_truthy, "CAS failed for (#{1.0 + 0.1}, true) => (1.2, false)"

    # Bignum
    atomic.set(2**100, false)
    expect(atomic.compare_and_set(2**100, 2**99, false, true))
      .to be_truthy, "CAS failed for (#{2**100}, false) => (0, true)"

    # Rational
    require 'rational' unless ''.respond_to? :to_r
    atomic.set(Rational(1, 3), true)
    expect(atomic.compare_and_set(Rational(1, 3), Rational(3, 1), true, false))
      .to be_truthy, "CAS failed for (#{Rational(1, 3)}, true) => (0, false)"

    # Complex
    require 'complex' unless ''.respond_to? :to_c
    atomic.set(Complex(1, 2), false)
    expect(atomic.compare_and_set(Complex(1, 2), Complex(1, 3), false, true))
      .to be_truthy, "CAS failed for (#{Complex(1, 2)}, false) => (0, false)"
  end
end

# Specs for platform specific implementations
module Concurrent
  module Edge
    describe AtomicMarkableReference do
      it_should_behave_like :atomic_markable_reference
    end

    if defined? Concurrent::CAtomicMarkableReference
      describe CAtomicMarkableReference do
        skip 'Unimplemented'
      end
    elsif defined? Concurrent::JavaAtomicMarkableReference
      describe JavaAtomicMarkableReference do
        skip 'Unimplemented'
      end
    elsif defined? Concurrent::RbxAtomicMarkableReference
      describe RbxAtomicMarkableReference do
        skip 'Unimplemented'
      end
    end

    describe AtomicMarkableReference do
      if ::Concurrent.on_jruby?
        it 'inherits from JavaAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      elsif ::Concurrent.allow_c_extensions?
        it 'inherits from CAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      elsif ::Concurrent.on_rbx?
        it 'inherits from RbxAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      else
        it 'inherits from MutexAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      end
    end

    if defined? Concurrent::CAtomicMarkableReference
      describe CAtomicMarkableReference do
        skip 'Unimplemented'
      end
    elsif defined? Concurrent::JavaAtomicMarkableReference
      describe JavaAtomicMarkableReference do
        skip 'Unimplemented'
      end
    elsif defined? Concurrent::RbxAtomicMarkableReference
      describe RbxAtomicMarkableReference do
        skip 'Unimplemented'
      end
    end

    describe AtomicMarkableReference do
      if ::Concurrent.on_jruby?
        it 'inherits from JavaAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      elsif ::Concurrent.allow_c_extensions?
        it 'inherits from CAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      elsif ::Concurrent.on_rbx?
        it 'inherits from RbxAtomicMarkableReference' do
          skip 'Unimplemented'
        end
      end
    end
  end
end

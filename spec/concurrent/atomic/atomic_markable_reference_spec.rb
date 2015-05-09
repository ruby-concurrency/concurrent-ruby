describe Concurrent::Edge::AtomicMarkableReference do
  # use a number outside JRuby's fixnum cache range, to ensure identity is
  # preserved
  subject { described_class.new 1000, true }

  specify :test_construct do
    expect(subject.value).to eq 1000
    expect(subject.marked?).to eq true
  end

  specify :test_set do
    val, mark = subject.set 1001, true

    expect(subject.value).to eq 1001
    expect(subject.marked?).to eq true

    expect(val).to eq 1001
    expect(mark).to eq true
  end

  specify :test_update do
    val, mark = subject.update { |v, m| [v + 1, !m] }

    expect(subject.value).to eq 1001
    expect(subject.marked?).to eq false

    expect(val).to eq 1001
    expect(mark).to eq false
  end

  specify :test_try_update do
    val, mark = subject.try_update { |v, m| [v + 1, !m] }

    expect(subject.value).to eq 1001

    expect(val).to eq 1001
    expect(mark).to eq false
  end

  specify :test_try_update_fails do
    expect do
      # assigning within block exploits implementation detail for test
      subject.try_update do |v, m|
        subject.set(1001, false)
        [v + 1, !m]
      end
    end.to raise_error Concurrent::ConcurrentUpdateError
  end

  specify :test_update_retries do
    tries = 0

    # assigning within block exploits implementation detail for test
    subject.update do |v, m|
      tries += 1
      subject.set(1001, false)
      [v + 1, !m]
    end

    expect(tries).to eq 2
  end

  specify :test_numeric_cas do
    # non-idempotent Float (JRuby, Rubinius, MRI < 2.0.0 or 32-bit)
    subject.set(1.0 + 0.1, true)
    expect(subject.compare_and_set(1.0 + 0.1, 1.2, true, false))
      .to be_truthy, "CAS failed for (#{1.0 + 0.1}, true) => (1.2, false)"

    # Bignum
    subject.set(2**100, false)
    expect(subject.compare_and_set(2**100, 2**99, false, true))
      .to be_truthy, "CAS failed for (#{2**100}, false) => (0, true)"

    # Rational
    require 'rational' unless ''.respond_to? :to_r
    subject.set(Rational(1, 3), true)
    expect(subject.compare_and_set(Rational(1, 3), Rational(3, 1), true, false))
      .to be_truthy, "CAS failed for (#{Rational(1, 3)}, true) => (0, false)"

    # Complex
    require 'complex' unless ''.respond_to? :to_c
    subject.set(Complex(1, 2), false)
    expect(subject.compare_and_set(Complex(1, 2), Complex(1, 3), false, true))
      .to be_truthy, "CAS failed for (#{Complex(1, 2)}, false) => (0, false)"
  end
end

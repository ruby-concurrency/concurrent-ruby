RSpec.shared_examples :semaphore do
  let(:semaphore) { described_class.new(3) }

  describe '#initialize' do
    it 'raises an exception if the initial count is not an integer' do
      expect {
        described_class.new('foo')
      }.to raise_error(ArgumentError)
    end

    context 'when initializing with 0' do
      let(:semaphore) { described_class.new(0) }

      it do
        expect(semaphore).to_not be nil
      end
    end

    context 'when initializing with -1' do
      let(:semaphore) { described_class.new(-1) }

      it do
        semaphore.release
        expect(semaphore.available_permits).to eq 0
      end
    end
  end

  describe '#acquire' do
    context 'permits available' do
      it 'should return true immediately' do
        result = semaphore.acquire
        expect(result).to be_nil
      end
    end

    context 'not enough permits available' do
      it 'should block thread until permits are available' do
        semaphore.drain_permits
        in_thread { sleep(0.2); semaphore.release }

        result = semaphore.acquire
        expect(result).to be_nil
        expect(semaphore.available_permits).to eq 0
      end
    end

    context 'when acquiring negative permits' do
      it do
        expect {
          semaphore.acquire(-1)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#drain_permits' do
    it 'drains all available permits' do
      drained = semaphore.drain_permits
      expect(drained).to eq 3
      expect(semaphore.available_permits).to eq 0
    end

    it 'drains nothing in no permits are available' do
      semaphore.reduce_permits 3
      drained = semaphore.drain_permits
      expect(drained).to eq 0
    end
  end

  describe '#try_acquire' do
    context 'without timeout' do
      it 'acquires immediately if permits are available' do
        result = semaphore.try_acquire(1)
        expect(result).to be_truthy
      end

      it 'returns false immediately in no permits are available' do
        result = semaphore.try_acquire(20)
        expect(result).to be_falsey
      end

      context 'when trying to acquire negative permits' do
        it do
          expect {
            semaphore.try_acquire(-1)
          }.to raise_error(ArgumentError)
        end
      end
    end

    context 'with timeout' do
      it 'acquires immediately if permits are available' do
        result = semaphore.try_acquire(1, 5)
        expect(result).to be_truthy
      end

      it 'acquires when permits are available within timeout' do
        semaphore.drain_permits
        in_thread { sleep 0.1; semaphore.release }
        result = semaphore.try_acquire(1, 1)
        expect(result).to be_truthy
      end

      it 'returns false on timeout' do
        semaphore.drain_permits
        result = semaphore.try_acquire(1, 0.1)
        expect(result).to be_falsey
      end
    end
  end

  describe '#reduce_permits' do
    it 'raises ArgumentError if reducing by negative number' do
      expect {
        semaphore.reduce_permits(-1)
      }.to raise_error(ArgumentError)
    end

    it 'reduces permits below zero' do
      semaphore.reduce_permits 1003
      expect(semaphore.available_permits).to eq(-1000)
    end

    it 'reduces permits' do
      semaphore.reduce_permits 1
      expect(semaphore.available_permits).to eq 2
      semaphore.reduce_permits 2
      expect(semaphore.available_permits).to eq 0
    end

    it 'reduces zero permits' do
      semaphore.reduce_permits 0
      expect(semaphore.available_permits).to eq 3
    end
  end

  describe '#release' do
    it 'increases the number of available permits by one' do
      semaphore.release
      expect(semaphore.available_permits).to eq 4
    end

    context 'when a number of permits is specified' do
      it 'increases the number of available permits by the specified value' do
        semaphore.release(2)
        expect(semaphore.available_permits).to eq 5
      end

      context 'when permits is set to negative number' do
        it do
          expect {
            semaphore.release(-1)
          }.to raise_error(ArgumentError)
        end
      end
    end
  end
end

module Concurrent
  RSpec.describe MutexSemaphore do
    it_should_behave_like :semaphore
  end

  if Concurrent.on_jruby?
    RSpec.describe JavaSemaphore do
      it_should_behave_like :semaphore
    end
  end

  RSpec.describe Semaphore do
    if Concurrent.on_jruby?
      it 'inherits from JavaSemaphore' do
        expect(Semaphore.ancestors).to include(JavaSemaphore)
      end
    else
      it 'inherits from MutexSemaphore' do
        expect(Semaphore.ancestors).to include(MutexSemaphore)
      end
    end
  end
end

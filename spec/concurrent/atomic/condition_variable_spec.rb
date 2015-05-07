require 'thread'

module Concurrent

  describe ConditionVariable do

    let(:mutex) { Mutex.new }

    context '#wait_until' do

      context 'when timeout is nil' do

        it 'immediately returns true if condition is true' do
          start = Concurrent::monotonic_time
          result = mutex.synchronize do
            subject.wait_until(mutex){ true }
          end
          expect(result).to be true
          expect(Concurrent.monotonic_time - start).to be <= 0.3
        end

        it 'does not wakeup if signaled and condition is false' do
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              subject.wait_until(mutex) do
                latch.wait unless latch.count == 0
                false
              end
            end
          end
          expect(t.join(0.1)).to be_nil
          latch.count_down
          subject.signal
          expect(t.join(0.1)).to be_nil
          t.kill
        end

        it 'wakes up and returns true when signaled and condition is true' do
          result = Concurrent::AtomicBoolean.new(false)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_until(mutex) do
                latch.wait unless latch.count == 0
                true
              end
            end
          end
          t.join(0.1)
          latch.count_down
          subject.signal
          t.join(0.1)
          expect(result.value).to be true
          t.kill
        end
      end

      context 'when given a timeout' do

        it 'immediately returns true if condition is true' do
          start = Concurrent::monotonic_time
          result = mutex.synchronize do
            subject.wait_until(mutex, 10){ true }
          end
          expect(result).to be true
          expect(Concurrent.monotonic_time - start).to be <= 0.3
        end

        it 'times out and returns false if signaled and condition is false' do
          result = Concurrent::AtomicBoolean.new(true)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_until(mutex, 0.1) do
                latch.wait unless latch.count == 0
                false
              end
            end
          end
          latch.count_down
          subject.signal
          t.join(0.2)
          expect(result.value).to be false
          t.kill
        end

        it 'times out and returns false if not signaled and condition is false' do
          result = Concurrent::AtomicBoolean.new(true)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_until(mutex, 0.1) do
                latch.wait unless latch.count == 0
                false
              end
            end
          end
          latch.count_down
          t.join(0.2)
          expect(result.value).to be false
          t.kill
        end

        it 'returns true before timeout if signaled and condition is true' do
          result = Concurrent::AtomicBoolean.new(false)
          latch = Concurrent::CountDownLatch.new
          start = Concurrent::monotonic_time
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_until(mutex, 1.0) do
                latch.wait unless latch.count == 0
                true
              end
            end
          end
          latch.count_down
          t.join(0.2)
          expect(Concurrent.monotonic_time - start).to be < 1.0
          expect(result.value).to be true
          t.kill
        end
      end
    end

    context '#wait_while' do

      context 'when timeout is nil' do

        it 'immediately returns true if condition is false' do
          start = Concurrent::monotonic_time
          result = mutex.synchronize do
            subject.wait_while(mutex){ false }
          end
          expect(result).to be true
          expect(Concurrent.monotonic_time - start).to be <= 0.3
        end

        it 'does not wakeup if signaled and condition is true' do
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              subject.wait_while(mutex) do
                latch.wait unless latch.count == 0
                true
              end
            end
          end
          expect(t.join(0.1)).to be_nil
          latch.count_down
          subject.signal
          expect(t.join(0.1)).to be_nil
          t.kill
        end

        it 'wakes up and returns true when signaled and condition is false' do
          result = Concurrent::AtomicBoolean.new(false)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_while(mutex) do
                latch.wait unless latch.count == 0
                false
              end
            end
          end
          t.join(0.1)
          latch.count_down
          subject.signal
          t.join(0.1)
          expect(result.value).to be true
          t.kill
        end
      end

      context 'when given a timeout' do

        it 'immediately returns true if condition is false' do
          start = Concurrent::monotonic_time
          result = mutex.synchronize do
            subject.wait_while(mutex){ false }
          end
          expect(result).to be true
          expect(Concurrent.monotonic_time - start).to be <= 0.3
        end

        it 'times out and returns false if signaled and condition is true' do
          result = Concurrent::AtomicBoolean.new(true)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_while(mutex, 0.1) do
                latch.wait unless latch.count == 0
                true
              end
            end
          end
          latch.count_down
          subject.signal
          t.join(0.2)
          expect(result.value).to be false
          t.kill
        end

        it 'times out and returns false if not signaled and condition is true' do
          result = Concurrent::AtomicBoolean.new(true)
          latch = Concurrent::CountDownLatch.new
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_while(mutex, 0.1) do
                latch.wait unless latch.count == 0
                true
              end
            end
          end
          latch.count_down
          t.join(0.2)
          expect(result.value).to be false
          t.kill
        end

        it 'returns true before timeout if signaled and condition is false' do
          result = Concurrent::AtomicBoolean.new(false)
          latch = Concurrent::CountDownLatch.new
          start = Concurrent::monotonic_time
          t = Thread.new do
            mutex.synchronize do
              result.value = subject.wait_while(mutex, 1.0) do
                latch.wait unless latch.count == 0
                false
              end
            end
          end
          latch.count_down
          t.join(0.2)
          expect(Concurrent.monotonic_time - start).to be < 1.0
          expect(result.value).to be true
          t.kill
        end
      end
    end
  end
end

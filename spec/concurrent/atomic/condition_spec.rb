module Concurrent

  describe Condition do

    context 'with no waiting threads' do
      describe '#signal' do
        it 'should return immediately' do
          expect(subject.signal).to be_truthy
        end
      end

      describe '#broadcast' do
        it 'should return immediately' do
          expect(subject.broadcast).to be_truthy
        end
      end
    end

    context 'with one waiting thread' do

      context 'signalled wake up' do

        describe '#wait without timeout' do

          it 'should block the thread' do
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new
            mutex = Mutex.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                subject.wait(mutex)
                latch_2.count_down
              end
            end

            latch_1.wait(1)
            latch_2.wait(0.1)
            expect(t.status).to eq 'sleep'
            expect(latch_2.count).to eq 1
            t.kill
          end

          it 'should return a woken up result when is woken up by #signal' do
            result = nil
            mutex = Mutex.new
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                result = subject.wait(mutex)
                latch_2.count_down
              end
            end

            latch_1.wait(1)

            mutex.synchronize do
              subject.signal
            end

            latch_2.wait(1)

            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be_nil
            expect(t.status).to be_falsey
          end

          it 'should return a woken up result when is woken up by #broadcast' do
            result = nil
            mutex = Mutex.new
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                result = subject.wait(mutex)
                latch_2.count_down
              end
            end

            latch_1.wait(1)

            mutex.synchronize do
              subject.broadcast
            end

            latch_2.wait(1)

            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be_nil
            expect(t.status).to be_falsey
          end
        end
      end

      context 'timeout' do

        describe '#wait' do

          it 'should block the thread' do
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new
            mutex = Mutex.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                subject.wait(mutex, 1)
                latch_2.count_down
              end
            end

            latch_1.wait(1)
            latch_2.wait(0.1)
            expect(t.status).to eq 'sleep'
            expect(latch_2.count).to eq 1
            t.kill
          end

          it 'should return remaining time when is woken up by #signal' do
            result = nil
            mutex = Mutex.new
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                result = subject.wait(mutex, 1)
                latch_2.count_down
              end
            end

            latch_1.wait(1)

            mutex.synchronize do
              sleep(0.1)
              subject.signal
            end

            latch_2.wait(1)

            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be < 1.0
            expect(t.status).to be_falsey
          end

          it 'should return remaining time when is woken up by #broadcast' do
            result = nil
            mutex = Mutex.new
            latch_1 = Concurrent::CountDownLatch.new
            latch_2 = Concurrent::CountDownLatch.new

            t = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                result = subject.wait(mutex, 1)
                latch_2.count_down
              end
            end

            latch_1.wait(1)

            mutex.synchronize do
              sleep(0.1)
              subject.broadcast
            end

            latch_2.wait(1)

            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be < 1.0
            expect(t.status).to be_falsey
          end

          it 'should return 0 or negative number if timed out' do
            result = nil
            mutex = Mutex.new
            latch = Concurrent::CountDownLatch.new

            t = Thread.new do
              mutex.synchronize do
                result = subject.wait(mutex, 0.1)
                latch.count_down
              end
            end

            latch.wait(1)

            expect(result).not_to be_woken_up
            expect(result).to be_timed_out
            expect(result.remaining_time).to be_less_than_or_equal_to(0)
            expect(t.status).to be_falsey
          end
        end
      end
    end

    context 'with many waiting threads' do

      context 'signalled wake up' do

        describe '#wait' do

          it 'should block threads' do
            mutex = Mutex.new
            latch = Concurrent::CountDownLatch.new(2)
            t1 = Thread.new { mutex.synchronize { latch.count_down; subject.wait(mutex) } }
            t2 = Thread.new { mutex.synchronize { latch.count_down; subject.wait(mutex) } }
            latch.wait(1)
            sleep(0.1)
            [t1, t2].each { |t| expect(t.status).to eq 'sleep' }
            [t1, t2].each { |t| t.kill }
          end
        end

        describe '#signal' do
          it 'wakes up only one thread' do
            latch_1 = Concurrent::CountDownLatch.new(2)
            latch_2 = Concurrent::CountDownLatch.new(2)
            mutex = Mutex.new

            t1 = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                subject.wait(mutex)
                latch_2.count_down
              end
            end

            t2 = Thread.new do
              mutex.synchronize do
                latch_1.count_down
                subject.wait(mutex)
                latch_2.count_down
              end
            end

            latch_1.wait(1)
            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.1)

            expect(latch_2.count).to eq 1
            [t1, t2].each { |t| t.kill }
          end
        end

        describe '#broadcast' do
          it 'wakes up all threads' do
            latch = CountDownLatch.new(2)
            mutex = Mutex.new

            t1 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }

            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.2)

            expect(latch.count).to eq 0
            [t1, t2].each { |t| t.kill }
          end
        end
      end
    end
  end
end

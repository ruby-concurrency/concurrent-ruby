module Concurrent

  describe Condition do

    let(:mutex) { Mutex.new }
    subject{ Condition.new }

    before(:each) do
      # rspec is not thread safe, without mutex initialization
      # we can experience race conditions
      mutex
    end

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
            t = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            sleep(0.1)
            expect(t.status).to eq 'sleep'
            t.kill
          end

          it 'should return a woken up result when is woken up by #signal' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex) } }
            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.1)
            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be_nil
            expect(t.status).to be_falsey
          end

          it 'should return a woken up result when is woken up by #broadcast' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex) } }
            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.1)
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
            t = Thread.new { mutex.synchronize { subject.wait(mutex, 1) } }
            sleep(0.1)
            expect(t.status).to eq 'sleep'
            t.kill
          end

          it 'should return remaining time when is woken up by #signal' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 1) } }
            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.1)
            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be_within(0.1).of(0.85)
            expect(t.status).to be_falsey
          end

          it 'should return remaining time when is woken up by #broadcast' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 1) } }
            sleep(0.1)
            mutex.synchronize { subject.broadcast }
            sleep(0.1)
            expect(result).to be_woken_up
            expect(result).not_to be_timed_out
            expect(result.remaining_time).to be_within(0.1).of(0.85)
            expect(t.status).to be_falsey
          end

          it 'should return 0 or negative number if timed out' do
            result = nil
            t = Thread.new { mutex.synchronize { result = subject.wait(mutex, 0.1) } }
            sleep(0.2)
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
            t1 = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex) } }
            sleep(0.1)
            [t1, t2].each { |t| expect(t.status).to eq 'sleep' }
            [t1, t2].each { |t| t.kill }
          end

        end

        describe '#signal' do
          it 'wakes up only one thread' do
            latch = CountDownLatch.new(2)

            t1 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }
            t2 = Thread.new { mutex.synchronize { subject.wait(mutex); latch.count_down } }

            sleep(0.1)
            mutex.synchronize { subject.signal }
            sleep(0.2)

            expect(latch.count).to eq 1
            [t1, t2].each { |t| t.kill }
          end
        end

        describe '#broadcast' do
          it 'wakes up all threads' do
            latch = CountDownLatch.new(2)

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

module Concurrent

  describe WaitGroup, edge: true do

    def go(prc, *args)
      Channel::Runtime.go(prc, *args)
    end

    def time
      start = Time.now
      yield
      return Time.now - start
    end

    context 'not added to' do

      it 'is done (private)' do
        wg = WaitGroup.new
        expect(wg.send(:done?)).to be true
      end

      it 'does not wait' do
        wg = WaitGroup.new
        wg.wait # expect { wg.wait }.to_return => watchdog?
      end

      it 'does not pop' do
        wg = WaitGroup.new
        expect { wg.done }.to raise_error(RuntimeError)
      end

    end

    context 'added to' do

      it 'is not done (private) when items are pending' do
        wg = WaitGroup.new
        wg.add(2)

        expect(wg.send(:done?)).to be false
      end

      it 'is done (private) when pending items have been resolved' do
        wg = WaitGroup.new
        wg.add(2)

        wg.done
        wg.done

        expect(wg.send(:done?)).to be true
      end

    end

    context 'waiting' do

      it 'waits until done' do
        wg = WaitGroup.new
        wg.add(1)
        go -> { sleep 0.3; wg.done }

        expect(time { wg.wait }).to be_within(0.05).of(0.3)
      end

      it 'cannot be reused' do
        wg = WaitGroup.new
        wg.add(1)
        go -> { sleep 0.3; wg.done }
        wg.wait

        expect { wg.add(1) }.to raise_error(RuntimeError)
      end

      it 'cannot be overused' do
        wg = WaitGroup.new
        wg.add(1)
        go -> { sleep 0.3; wg.done }
        wg.wait

        expect { wg.done }.to raise_error(RuntimeError)
      end

      it 'waits concurrently' do
        wg = WaitGroup.new
        wg.add(2)
        ok1 = false
        ok2 = false

        go -> { sleep 0.2; ok1 = true; wg.done }
        go -> { sleep 0.5; ok2 = true; wg.done }
        
        expect(time { wg.wait }).to be_within(0.05).of(0.5)
        expect(ok1).to eq true
        expect(ok2).to eq true
      end

      it 'raises an exception when adding concurrently' do
        wg = WaitGroup.new
        go -> { wg.wait }
        sleep 0.1

        expect { wg.add(1) }.to raise_error(RuntimeError)
      end

    end

  end

end

require 'spec_helper'

module Concurrent

  describe SmartMutex do

    subject{ SmartMutex.new }

    def fly_solo
      Thread.stub(:list).and_return(Array.new)
    end

    def run_with_the_pack
      Thread.stub(:list).and_return([1,2,3,4])
    end

    context '#initialize' do

      it 'creates a new mutex' do
        Mutex.should_receive(:new).with(no_args())
        SmartMutex.new
      end
    end

    context '#alone?' do

      it 'returns true when there is only one thread' do
        fly_solo
        subject.alone?.should be_true
      end

      it 'returns false when there is more than one thread' do
        run_with_the_pack
        subject.alone?.should be_false
      end
    end

    context '#lock' do

      it 'does not lock when there is only one thread' do
        fly_solo

        mutex = Mutex.new
        mutex.should_not_receive(:lock)
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        subject.lock
      end

      it 'locks when not locked and there is more than one thread' do
        run_with_the_pack

        mutex = Mutex.new
        mutex.should_receive(:lock)
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        subject.lock
      end

      it 'raises an exception when locked and there is more than one thread' do
        run_with_the_pack
        subject.lock
        lambda {
          subject.lock
        }.should raise_error(ThreadError)
      end

      it 'does not raise an exception when lock called twice and there is only one thread' do
        fly_solo
        subject.lock
        lambda {
          subject.lock
        }.should_not raise_error
      end

      it 'returns self' do
        fly_solo
        mutex = SmartMutex.new
        mutex.lock.should eq mutex

        run_with_the_pack
        mutex.lock.should eq mutex
      end
    end

    context '#locked?' do

      it 'returns false when there is only one thread' do
        fly_solo
        subject.should_not be_locked
      end

      it 'returns true when locked and there is more than one thread' do
        run_with_the_pack
        subject.lock
        subject.should be_locked
      end

      it 'returns false when not locked and there is more than one thread' do
        run_with_the_pack
        subject.should_not be_locked
      end
    end

    context '#sleep' do

      it 'sleeps when there is only one thread' do
        fly_solo
        Kernel.should_receive(:sleep).with(0.1).and_return(0.1)
        subject.sleep(0.1)
      end

      it 'sleeps when locked and there is more than one thread' do
        mutex = Mutex.new
        mutex.should_receive(:sleep).with(0.1).and_return(0.1)
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        run_with_the_pack
        subject.lock
        subject.sleep(0.1)
      end

      it 'raises an exception when not locked and there is more than one thread' do
        run_with_the_pack
        lambda {
          subject.sleep(0.1)
        }.should raise_error(ThreadError)
      end

      it 'returns the number of seconds slept' do
        fly_solo
        subject.sleep(1).should eq 1

        run_with_the_pack
        subject.lock
        subject.sleep(1).should eq 1
      end
    end

    context '#synchronize' do

      it 'yields to the block when there is only one thread' do
        fly_solo
        @expected = false
        subject.synchronize{ @expected = true }
        @expected.should be_true
      end

      it 'locks when there is more than one thread' do
        mutex = Mutex.new
        mutex.should_receive(:synchronize).with(no_args())
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        run_with_the_pack
        subject.synchronize{ nil }
      end

      it 'yields to the block when there is more than one thread' do
        run_with_the_pack
        @expected = false
        subject.synchronize{ @expected = true }
        @expected.should be_true
      end

      it 'returns the result of the block' do
        fly_solo
        subject.synchronize{ 42 }.should eq 42

        run_with_the_pack
        subject.synchronize{ 42 }.should eq 42
      end
    end

    context '#try_lock' do

      it 'returns true when there is only one thread' do
        fly_solo
        subject.try_lock.should be_true
      end

      it 'returns true when the lock is obtained and there is more than one thread' do
        run_with_the_pack
        subject.try_lock.should be_true
      end

      it 'returns false when the lock is not obtained and there is more than one thread' do
        run_with_the_pack
        subject.lock
        subject.try_lock.should be_false
      end
    end

    context '#unlock' do

      it 'does not unlock when there is only one thread' do
        fly_solo

        mutex = Mutex.new
        mutex.should_not_receive(:unlock)
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        subject.unlock
      end

      it 'unlocks when locked and there is more than one thread' do
        run_with_the_pack

        mutex = Mutex.new
        mutex.should_receive(:unlock)
        Mutex.should_receive(:new).with(no_args()).and_return(mutex)

        subject.lock
        subject.unlock
      end

      it 'raises an exception when not locked and there is more than one thread' do
        run_with_the_pack
        lambda {
          subject.unlock
        }.should raise_error(ThreadError)
      end

      it 'returns self' do
        fly_solo
        mutex = SmartMutex.new
        mutex.unlock.should eq mutex

        run_with_the_pack
        mutex.lock
        mutex.unlock.should eq mutex
      end
    end
  end
end

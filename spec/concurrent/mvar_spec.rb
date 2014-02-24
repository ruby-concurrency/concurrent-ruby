require 'spec_helper'

module Concurrent

  describe MVar do

    context '#initialize' do

      it 'accepts no initial value' do
        m = MVar.new
        m.should be_empty
      end

      it 'accepts an empty initial value' do
        m = MVar.new(MVar::EMPTY)
        m.should be_empty
      end

      it 'accepts an initial value' do
        m = MVar.new(14)
        m.should_not be_empty
      end

      it 'accepts a nil initial value' do
        m = MVar.new(nil)
        m.should_not be_empty
      end

    end

    context '#take' do

      it 'sets the MVar to empty' do
        m = MVar.new(14)
        m.take
        m.should be_empty
      end

      it 'returns the value on a full MVar' do
        m = MVar.new(14)
        m.take.should eq 14
      end

      it 'waits for another thread to #put' do
        m = MVar.new

        putter = Thread.new {
          sleep(0.5)
          m.put 14 
        }

        m.take.should eq 14
      end

      it 'returns TIMEOUT on timeout on an empty MVar' do
        m = MVar.new
        m.take(0.5).should eq MVar::TIMEOUT
      end

    end

    context '#put' do

      it 'sets the MVar to be empty' do
        m = MVar.new(14)
        m.take
        m.should be_empty
      end

      it 'sets a new value on an empty MVar' do
        m = MVar.new
        m.put 14
        m.take.should eq 14
      end

      it 'waits for another thread to #take' do
        m = MVar.new(14)

        putter = Thread.new {
          sleep(0.5)
          m.take
        }

        m.put(14).should eq 14
      end

      it 'returns TIMEOUT on timeout on a full MVar' do
        m = MVar.new(14)
        m.put(14, 0.5).should eq MVar::TIMEOUT
      end

      it 'returns the value' do
        m = MVar.new
        m.put(14).should eq 14
      end

    end

    context '#empty?' do

      it 'returns true on an empty MVar' do
        m = MVar.new
        m.should be_empty
      end

      it 'returns false on a full MVar' do
        m = MVar.new(14)
        m.should_not be_empty
      end

    end

    context '#full?' do

      it 'returns false on an empty MVar' do
        m = MVar.new
        m.should_not be_full
      end

      it 'returns true on a full MVar' do
        m = MVar.new(14)
        m.should be_full
      end

    end

    context '#modify' do

      it 'raises an exception when no block given' do
        m = MVar.new(14)
        expect { m.modify }.to raise_error(ArgumentError)
      end

      it 'modifies a full MVar' do
        m = MVar.new(14)
        m.modify{ |v| v + 2 }
        m.take.should eq 16
      end

      it 'returns the unmodified value' do
        m = MVar.new(14)
        m.modify{ |v| v + 2 }.should eq 14
      end

      it 'waits for another thread to #put' do
        m = MVar.new

        putter = Thread.new {
          sleep(0.5)
          m.put 14 
        }

        m.modify{ |v| v + 2 }.should eq 14
      end

      it 'is atomic' do
        m = MVar.new(0)

        # #modify conceptually does #take and #put - but it should be atomic.
        # Check that another #put can't sneak it during the #modify.

        modifier = Thread.new {
          m.modify do |v|
            sleep(1)
            1
          end
        }

        sleep(0.5)
        m.put(2, 1).should eq MVar::TIMEOUT
        m.take.should eq 1
      end

      it 'returns TIMEOUT on timeout on an empty MVar' do
        m = MVar.new
        m.modify(0.5){ |v| v + 2 }.should eq MVar::TIMEOUT
      end

    end

  end

end

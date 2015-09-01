module Concurrent::Edge

  class Channel

    describe Tick do

      it 'initializes to current time when no argument given' do
        allow(Concurrent).to receive(:monotonic_time).and_return(42)
        subject = Tick.new
        expect(subject.monotonic).to eq 42
      end

      it 'initializes to the given monotonic time' do
        m = Concurrent.monotonic_time
        subject = Tick.new(m)
        expect(subject.monotonic).to eq m
      end

      specify '#utc returns a Time object in UTC' do
        t = subject.utc
        expect(subject.utc).to be_a Time
        expect(subject.utc.zone).to eq 'UTC'
      end

      specify '#epoch returns the UTC time as epoch seconds' do
        expect(subject.utc.to_f).to eq subject.epoch
      end

      context 'comparison' do

        it 'correctly compares to a Numeric (monotonic)' do
          present = Concurrent.monotonic_time
          past = present - 42
          future = present + 42

          subject = Tick.new(present)

          expect(subject).to be <  future
          expect(subject).to be == present
          expect(subject).to be >  past
        end

        it 'correctly compares to a Time' do
          present = Time.now
          past = Time.now - 42*60*60
          future = Time.now + 42*60*60

          subject = Tick.new

          expect(subject).to be < future
          expect(subject).to be > past
        end

        it 'correctly compares to a Tick' do
          now = Concurrent.monotonic_time
          present = Tick.new(now)
          past = Tick.new(now - 42)
          future = Tick.new(now + 42)

          subject = Tick.new(now)

          expect(subject).to be < future
          expect(subject).to eq present
          expect(subject).to be > past
        end
      end
    end
  end
end

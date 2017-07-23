module Concurrent
  describe Array do
    let!(:ary) { described_class.new }

    it 'concurrency' do
      (1..THREADS).map do |i|
        Thread.new do
          1000.times do
            ary << i
            ary.each { |x| x * 2 }
            ary.shift
            ary.last
          end
        end
      end.map(&:join)
    end

    describe '#slice' do
      # This is mostly relevant on Rubinius and Truffle
      it 'correctly initializes the monitor' do
        ary.concat([0, 1, 2, 3, 4, 5, 6, 7, 8])

        sliced = ary.slice!(0..2)
        expect { sliced[0] }.not_to raise_error
      end
    end
  end
end

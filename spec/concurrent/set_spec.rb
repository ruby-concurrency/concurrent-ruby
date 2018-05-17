require 'set'
module Concurrent
  RSpec.describe Set do
    let!(:set) { described_class.new }

    it 'concurrency' do
      (1..Concurrent::ThreadSafe::Test::THREADS).map do |i|
        in_thread do
          1000.times do
            v = i
            set << v
            expect(set).not_to be_empty
            set.delete(v)
          end
        end
      end.map(&:join)
      expect(set).to be_empty
    end
  end
end

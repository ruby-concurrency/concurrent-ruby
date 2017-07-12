require 'set' 
module Concurrent
  describe Set do 
    let!(:set) { described_class.new }

    it 'concurrency' do
      (1..THREADS).map do |i|
        Thread.new do
           1000.times do |j|
            set << i 
            set.empty?
            set.delete(i)
           end
        end
      end.map(&:join)
    end
  end
end 
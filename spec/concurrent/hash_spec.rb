module Concurrent
  RSpec.describe Hash do
    let!(:hsh) { described_class.new }

    context 'concurrency' do
      it do
        (1..Concurrent::ThreadSafe::Test::THREADS).map do |i|
          in_thread do
            1000.times do |j|
              hsh[i * 1000 + j] = i
              expect(hsh[i * 1000 + j]).to eq(i)
              expect(hsh.delete(i * 1000 + j)).to eq(i)
            end
          end
        end.map(&:join)
        expect(hsh).to be_empty
      end
    end
  end
end

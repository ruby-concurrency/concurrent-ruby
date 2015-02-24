require 'spec_helper'
require 'benchmark'

module Concurrent
  describe Parallel do
    describe '#any? (parallelizable, value-returning)' do
      it 'should produce the correct result' do
        result = Parallel.new([1, 2, 3]).any? { |x| x == 3 }

        expect(result).to be_truthy
      end

      it 'should run given block in parallel' do
        time = Benchmark.measure do
          Parallel.new([1, 2, 3]).any? { sleep 0.1 }
        end

        expect(time.real).to be < 0.2
      end
    end

    describe '#each (parallelizable, self-returning)' do
      it 'should produce the correct result' do
        result = Parallel.new([1, 2, 3]).each { |x| x * 2 }

        expect(result).to eq [1, 2, 3]
      end

      it 'should run given block in parallel' do
        time = Benchmark.measure do
          Parallel.new([1, 2, 3]).each { sleep 0.1 }
        end

        expect(time.real).to be < 0.2
      end
    end

    describe '#map (parallelizable, Parallel-returning)' do
      it 'should produce the correct result' do
        result = Parallel.new([1, 2, 3]).map { |x| x * 2 }

        expect(result).to eq [2, 4, 6]
      end

      it 'should run given block in parallel' do
        time = Benchmark.measure do
          Parallel.new([1, 2, 3]).map { sleep 0.1 }
        end

        expect(time.real).to be < 0.2
      end

      it 'should return a Parallel' do
        result = Parallel.new([1, 2, 3]).map { |x| x * 2 }

        expect(result).to be_a Parallel
      end
    end

    describe '#reduce (non-parallelizable)' do
      it 'should produce the correct result' do
        result = Parallel.new([1, 2, 3]).reduce { |x, m| m + x }

        expect(result).to eq 6
      end
    end
  end
end

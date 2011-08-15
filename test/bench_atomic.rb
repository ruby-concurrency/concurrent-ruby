require 'benchmark'
require 'atomic'
require 'thread'

N = 100_000
@lock = Mutex.new
@atom = Atomic.new(0)

Benchmark.bm(10) do |x|
  x.report "simple" do
    value = 0
    N.times do
      value += 1
    end
  end
  x.report "mutex" do
    value = 0
    N.times do
      @lock.synchronize do
        value += 1
      end
    end
  end
  x.report "atomic" do
    N.times do
      @atom.update{|x| x += 1}
    end
  end
end

require 'benchmark'
require 'concurrent'
require 'thread'
Thread.abort_on_exception = true

$go = false # for synchronizing parallel threads

# number of updates on the value
N = ARGV[1] ? ARGV[1].to_i : 100_000

# number of threads for parallel test
M = ARGV[0] ? ARGV[0].to_i : 100


puts "*** Sequential updates ***"
Benchmark.bm(10) do |x|
  value = 0
  x.report "no lock" do
    N.times do
      value += 1
    end
  end

  @lock = Mutex.new
  x.report "mutex" do
    value = 0
    N.times do
      @lock.synchronize do
        value += 1
      end
    end
  end

  @atom = Concurrent::Atomic.new(0)
  x.report "atomic" do
    N.times do
      @atom.update{|x| x += 1}
    end
  end
end

def para_setup(num_threads, count, &block)
  if num_threads % 2 > 0
    raise ArgumentError, "num_threads must be a multiple of two"
  end
  raise ArgumentError, "need block" unless block_given?

  # Keep those threads together
  tg = ThreadGroup.new

  num_threads.times do |i|
    diff = (i % 2 == 0) ? 1 : -1

    t = Thread.new do
      nil until $go
      count.times do
        yield diff
      end
    end

    tg.add(t)
  end

  # Make sure all threads are started
  while tg.list.find{|t| t.status != "run"}
    Thread.pass
  end

  # For good measure
  GC.start

  tg
end

def para_run(tg)
  $go = true
  tg.list.each{|t| t.join}
  $go = false
end

puts "*** Parallel updates ***"
Benchmark.bm(10) do |bm|
  # This is not secure
  value = 0
  tg = para_setup(M, N/M) do |diff|
    value += diff
  end
  bm.report("no lock"){ para_run(tg) }


  value = 0
  @lock = Mutex.new
  tg = para_setup(M, N/M) do |diff|
    @lock.synchronize do
      value += diff
    end
  end
  bm.report("mutex"){ para_run(tg) }
  raise unless value == 0


  @atom = Concurrent::Atomic.new(0)
  tg = para_setup(M, N/M) do |diff|
    @atom.update{|x| x + diff}
  end
  bm.report("atomic"){ para_run(tg) }
  raise unless @atom.value == 0

end

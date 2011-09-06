require 'benchmark'
require 'atomic'
require 'thread'
Thread.abort_on_exception = true

# number of updates on the value
N = ARGV[1] ? ARGV[1].to_i : 100_000

# number of threads for parallel test
M = ARGV[0] ? ARGV[0].to_i : 100


puts "*** Sequencial updates ***"
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

  @atom = Atomic.new(0)
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
      Thread.stop # don't run until we get the go
      count.times do
        yield diff
      end
    end

    tg.add(t)
  end

  # Make sure all threads are paused
  while tg.list.find{|t| t.status != "sleep"}
    Thread.pass
  end

  # For good measure
  GC.start

  tg
end

def para_run(tg)
  Thread.exclusive do
    tg.list.each{|t| t.run }
  end
  tg.list.each{|t| t.join}
end


puts "*** Parallel updates ***"
Benchmark.bm(10) do |x|
  # This is not secure
  value = 0
  tg = para_setup(M, N/M) do |diff|
    value += diff
  end
  x.report("no lock"){ para_run(tg) }


  value = 0
  @lock = Mutex.new
  tg = para_setup(M, N/M) do |diff|
    @lock.synchronize do
      value += diff
    end
  end
  x.report("mutex"){ para_run(tg) }
  raise unless value == 0


  @atom = Atomic.new(0)
  tg = para_setup(M, N/M) do |diff|
    @atom.update{|x| x + diff}
  end
  x.report("atomic"){ para_run(tg) }
  raise unless @atom.value == 0

end

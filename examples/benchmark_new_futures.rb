require 'benchmark/ips'
require 'concurrent'
require 'concurrent-edge'

scale  = 1
time   = 10 * scale
warmup = 2 * scale
warmup *= 10 if Concurrent.on_jruby?

Benchmark.ips(time, warmup) do |x|
  x.report('status-old') { f = Concurrent::Promise.execute { nil }; 100.times { f.complete? } }
  x.report('status-new') { f = Concurrent.future(:fast) { nil }; 100.times { f.completed? } }
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  of = Concurrent::Promise.execute { 1 }
  nf = Concurrent.future(:fast) { 1 }
  x.report('value-old') { of.value! }
  x.report('value-new') { nf.value! }
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  x.report('graph-old') do
    head = Concurrent::Promise.execute { 1 }
    10.times do
      branch1 = head.then(&:succ)
      branch2 = head.then(&:succ).then(&:succ)
      head    = Concurrent::Promise.zip(branch1, branch2).then { |a, b| a + b }
    end
    head.value!
  end
  x.report('graph-new') do
    head = Concurrent.future(:fast) { 1 }
    10.times do
      branch1 = head.then(&:succ)
      branch2 = head.then(&:succ).then(&:succ)
      head    = (branch1 & branch2).then { |a, b| a + b }
    end
    head.value!
  end
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  x.report('immediate-old') { Concurrent::Promise.execute { nil }.value! }
  x.report('immediate-new') { Concurrent.future(:fast) { nil }.value! }
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  of = Concurrent::Promise.execute { 1 }
  nf = Concurrent.future(:fast) { 1 }
  x.report('then-old') { 100.times.reduce(nf) { |nf, _| nf.then(&:succ) }.value! }
  x.report('then-new') { 100.times.reduce(nf) { |nf, _| nf.then(&:succ) }.value! }
  x.compare!
end

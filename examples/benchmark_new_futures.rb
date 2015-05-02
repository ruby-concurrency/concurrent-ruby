require 'benchmark/ips'
require 'concurrent'
require 'concurrent-edge'

scale  = 1
time   = 10 * scale
warmup = 2 * scale
warmup *= 10 if Concurrent.on_jruby?


Benchmark.ips(time, warmup) do |x|
  of = Concurrent::Promise.execute { 1 }
  nf = Concurrent.future { 1 }
  x.report('value-old') { of.value! }
  x.report('value-new') { nf.value! }
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  x.report('graph-old') do
    head    = Concurrent::Promise.execute { 1 }
    branch1 = head.then(&:succ)
    branch2 = head.then(&:succ).then(&:succ)
    Concurrent::Promise.zip(branch1, branch2).then { |(a, b)| a + b }.value!
  end
  x.report('graph-new') do
    head    = Concurrent.future { 1 }
    branch1 = head.then(&:succ)
    branch2 = head.then(&:succ).then(&:succ)
    (branch1 + branch2).then { |(a, b)| a + b }.value!
  end
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  x.report('immediate-old') { Concurrent::Promise.execute { nil }.value! }
  x.report('immediate-new') { Concurrent.future { nil }.value! }
  x.compare!
end

Benchmark.ips(time, warmup) do |x|
  of = Concurrent::Promise.execute { 1 }
  nf = Concurrent.future { 1 }
  x.report('then-old') { of.then(&:succ).then(&:succ).value! }
  x.report('then-new') { nf.then(&:succ).then(&:succ).value! }
  x.compare!
end


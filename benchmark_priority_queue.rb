require 'concurrent'
require 'benchmark'

count = ARGV.first || 1

if RUBY_PLATFORM == 'java'
  runtime = java.lang.Runtime.getRuntime
  puts 'before:'
  puts "maxMemory #=> #{runtime.maxMemory}"
  puts "freeMemory #=> #{runtime.freeMemory}"
  puts 
  puts 'after:'
end

pq = Concurrent::MutexPriorityQueue.new

count.to_i.times do
  puts Benchmark.measure { 10_000_000.times { pq << rand } }
  puts "freeMemory #=> #{runtime.freeMemory}" if RUBY_PLATFORM == 'java'
end

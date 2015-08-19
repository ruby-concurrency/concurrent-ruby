#!/usr/bin/env ruby

require "benchmark"
require "concurrent"

hash  = {}
map = Concurrent::Map.new

ENTRIES = 10_000

ENTRIES.times do |i|
  hash[i]  = i
  map[i] = i
end

TESTS = 40_000_000
Benchmark.bmbm do |results|
  key = rand(10_000)

  results.report('Hash#[]') do
    TESTS.times { hash[key] }
  end

  results.report('Map#[]') do
    TESTS.times { map[key] }
  end

  results.report('Hash#each_pair') do
    (TESTS / ENTRIES).times { hash.each_pair {|k,v| v} }
  end

  results.report('Map#each_pair') do
    (TESTS / ENTRIES).times { map.each_pair {|k,v| v} }
  end
end

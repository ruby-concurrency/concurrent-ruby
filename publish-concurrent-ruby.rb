#!/usr/bin/env ruby

# get the current gem version
require_relative './lib/concurrent/version'

GEMS = [
  "concurrent-ruby-#{Concurrent::VERSION}.gem",
  "concurrent-ruby-#{Concurrent::VERSION}-java.gem",
  "concurrent-ruby-ext-#{Concurrent::VERSION}.gem",
  "concurrent-ruby-ext-#{Concurrent::VERSION}-x86-mingw32.gem",
  "concurrent-ruby-ext-#{Concurrent::VERSION}-x64-mingw32.gem",
  "concurrent-ruby-edge-#{Concurrent::EDGE_VERSION}.gem",
]

GEMS.each do |gem|
  file = File.join("pkg", gem)
  basename = File.basename(file)
  puts "Publishing #{basename}..."
  `gem push #{file}`
end

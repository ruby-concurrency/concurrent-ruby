require 'concurrent'
require_relative 'stresstest/support/word_sec.rb'

namespace :stresstest do

  DEFAULT_NUM_TESTS = 1000
  DEFAULT_NUM_THREADS = Concurrent::FixedThreadPool::MAX_POOL_SIZE
  SPEC_DIR = File.join(File.dirname(__FILE__), 'stresstest')

  def rspec_command(args, glob)
    cmd = <<-CMD
TESTS=#{args[:tests]} \
THREADS=#{args[:threads]} \
bundle exec rspec -fd --color #{SPEC_DIR}/#{glob}_spec.rb
    CMD
  end

  desc 'Stress test the gem'
  task :all, :tests, :threads do |t, args|
    args.with_defaults(:tests => DEFAULT_NUM_TESTS, :threads => DEFAULT_NUM_THREADS)
    sh rspec_command(args, '*')
  end

  desc 'Stress test Concurrent::CachedThreadPool'
  task :cached_thread_pool, :tests, :threads do |t, args|
    args.with_defaults(:tests => DEFAULT_NUM_TESTS, :threads => DEFAULT_NUM_THREADS)
    sh rspec_command(args, 'cached_thread_pool_stress_test')
  end

  desc 'Stress test Concurrent::FixedThreadPool'
  task :fixed_thread_pool, :tests, :threads do |t, args|
    args.with_defaults(:tests => DEFAULT_NUM_TESTS, :threads => DEFAULT_NUM_THREADS)
    sh rspec_command(args, 'fixed_thread_pool_stress_test')
  end
end

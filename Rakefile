require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rake/javaextensiontask'

GEMSPEC = Gem::Specification.load('concurrent-ruby.gemspec')
EXTENSION_NAME = 'concurrent_ruby_ext'

Bundler::GemHelper.install_tasks

$:.push File.join(File.dirname(__FILE__), 'lib')
require 'extension_helper'

def safe_load(file)
  begin
    load file
  rescue LoadError => ex
    puts 'Error loading rake tasks, but will continue...'
    puts ex.message
  end
end

Dir.glob('tasks/**/*.rake').each do |rakefile|
  safe_load rakefile
end

desc 'Run benchmarks'
task :bench do
  exec 'ruby -Ilib -Iext examples/bench_atomic.rb'
end

if defined?(JRUBY_VERSION)

  Rake::JavaExtensionTask.new(EXTENSION_NAME, GEMSPEC) do |ext|
    ext.ext_dir = 'ext'
  end

else
  task :clean
  task :compile
  task "compile:#{EXTENSION_NAME}"
end

Rake::Task[:clean].enhance do
  rm_rf 'pkg/classes'
  rm_rf 'tmp'
  rm_f Dir.glob('./lib/*.jar')
end

begin
  require 'rspec'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--color --backtrace --format documentation'
  end

  task :default => [:clean, :compile, :spec]
rescue LoadError
  puts 'Error loading Rspec rake tasks, probably building the gem...'
end

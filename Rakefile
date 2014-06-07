require 'rake'
require 'bundler/gem_tasks'
require 'rspec'
require 'rspec/core/rake_task'

require_relative 'lib/extension_helper'

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec)
$:.unshift 'tasks'
Dir.glob('tasks/**/*.rake').each do|rakefile|
  load rakefile
end

desc "Run benchmarks"
task :bench do
  exec "ruby -Ilib -Iext examples/bench_atomic.rb"
end

desc 'Clean up build artifacts'
task :clean do
  rm_rf 'pkg/classes'
  rm_f  'lib/*.jar'
  rm_rf '**/*.{o,so,bundle}'
end

if defined?(JRUBY_VERSION)
  require 'ant'

  EXTENSION_NAME = 'concurrent_jruby'

  directory 'pkg/classes'

  desc 'Compile the extension'
  task :compile => 'pkg/classes' do |t|
    ant.javac :srcdir => 'ext', :destdir => t.prerequisites.first,
      :source => '1.5', :target => '1.5', :debug => true,
      :classpath => '${java.class.path}:${sun.boot.class.path}'
  end

  desc 'Build the jar'
  task :jar => :compile do
    ant.jar :basedir => 'pkg/classes', :destfile => "lib/#{EXTENSION_NAME}.jar", :includes => '**/*.class'
  end

  task :compile_java => :jar

elsif use_c_extensions?

  EXTENSION_NAME = 'concurrent_cruby'

  require 'rake/extensiontask'

  spec = Gem::Specification.load('concurrent-ruby.gemspec')
  Rake::ExtensionTask.new(EXTENSION_NAME, spec) do |ext|
    ext.ext_dir = 'ext'
    ext.name = EXTENSION_NAME
    ext.source_pattern = "**/*.{h,c,cpp}"
  end

  task :return_dummy_makefile do
    sh "git co ext/Makefile"
  end

  desc 'Clean, compile, and build the extension from scratch'
  task :compile_c => [ :clean, :compile, :return_dummy_makefile ]

  task :irb => [:compile] do
    sh "irb -r ./lib/#{EXTENSION_NAME}.bundle -I #{File.join(File.dirname(__FILE__), 'lib')}"
  end
end

RSpec::Core::RakeTask.new(:travis_spec) do |t|
  t.rspec_opts = '--tag ~@not_on_travis'
end

if defined?(JRUBY_VERSION)
  task :default => [:compile_java, :travis_spec]
elsif use_c_extensions?
  task :default => [:compile_c, :travis_spec]
else
  task :default => [:clean, :travis_spec]
end

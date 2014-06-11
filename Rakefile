require 'rake'
require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rake/javaextensiontask'
#require 'rspec'
#require 'rspec/core/rake_task'

GEMSPEC = Gem::Specification.load(File.expand_path('../concurrent-ruby.gemspec', __FILE__))

$:.push File.join(File.dirname(__FILE__), 'lib')
require 'extension_helper'

Bundler::GemHelper.install_tasks

#RSpec::Core::RakeTask.new(:spec)
#$:.unshift 'tasks'
#Dir.glob('tasks/**/*.rake').each do|rakefile|
  #load rakefile
#end

desc 'Run benchmarks'
task :bench do
  exec 'ruby -Ilib -Iext examples/bench_atomic.rb'
end

if defined?(JRUBY_VERSION)

  EXTENSION_NAME = 'concurrent_jruby'

  Rake::JavaExtensionTask.new(EXTENSION_NAME, GEMSPEC) do |ext|
    ext.ext_dir = 'ext'
  end

elsif Concurrent.use_c_extensions?

  EXTENSION_NAME = 'concurrent_cruby'

  Rake::ExtensionTask.new(EXTENSION_NAME, GEMSPEC) do |ext|
    ext.ext_dir = 'ext'
    ext.cross_compile = true
    ext.cross_platform = ['x86-mingw32', 'x64-mingw32']
  end

  ENV['RUBY_CC_VERSION'].to_s.split(':').each do |ruby_version|
    platforms = {
      'x86-mingw32' => 'i686-w64-mingw32',
      'x64-mingw32' => 'x86_64-w64-mingw32'
    }
    platforms.each do |platform, prefix|
      task "copy:#{EXTENSION_NAME}:#{platform}:#{ruby_version}" do |t|
        %w[lib tmp/#{platform}/stage/lib].each do |dir|
          so_file = "#{dir}/#{ruby_version[/^\d+\.\d+/]}/#{EXTENSION_NAME}.so"
          if File.exists?(so_file)
            sh "#{prefix}-strip -S #{so_file}"
          end
        end
      end
    end
  end
end

Rake::Task[:clean].enhance do
  rm_rf 'pkg'
  rm_f Dir.glob('./lib/*.jar')
  rm_f Dir.glob('./lib/*.bundle')
end

#RSpec::Core::RakeTask.new(:travis_spec) do |t|
  #t.rspec_opts = '--tag ~@not_on_travis'
#end

#if defined?(EXTENSION_NAME)
  #task :default => [:clean, "compile:#{EXTENSION_NAME}", :travis_spec]
#else
  #task :default => [:clean, :travis_spec]
#end

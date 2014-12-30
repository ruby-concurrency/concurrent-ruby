CORE_GEMSPEC = Gem::Specification.load('concurrent-ruby.gemspec')
EXT_GEMSPEC = Gem::Specification.load('concurrent-ruby-ext.gemspec')
GEM_NAME = 'concurrent-ruby'
EXTENSION_NAME = 'extension'

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

if defined?(JRUBY_VERSION)
  require 'rake/javaextensiontask'

  Rake::JavaExtensionTask.new('concurrent_ruby_ext', CORE_GEMSPEC) do |ext|
    ext.ext_dir = 'ext'
  end

elsif Concurrent.allow_c_extensions?
  require 'rake/extensiontask'

  Rake::ExtensionTask.new(EXTENSION_NAME, EXT_GEMSPEC) do |ext|
    ext.ext_dir = 'ext/concurrent'
    ext.lib_dir = 'lib/concurrent'
    ext.source_pattern = '*.{c,h}'
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
else
  task :compile
end

task :clean do
  rm_rf 'pkg/classes'
  rm_rf 'tmp'
  rm_rf 'lib/1.9'
  rm_rf 'lib/2.0'
  rm_f Dir.glob('./**/*.so')
  rm_f Dir.glob('./**/*.bundle')
  rm_f Dir.glob('./lib/*.jar')
  mkdir_p 'pkg'
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

build_deps = [:clean]
build_deps << :compile if defined?(JRUBY_VERSION)

build_tasks = ['build:core']
build_tasks += ['build:ext', 'build:native'] if Concurrent.allow_c_extensions?

CoreGem = "#{GEM_NAME}-#{Concurrent::VERSION}.gem"
ExtensionGem = "#{GEM_NAME}-ext-#{Concurrent::VERSION}.gem"
NativeGem = "#{GEM_NAME}-ext-#{Concurrent::VERSION}-#{Gem::Platform.new(RUBY_PLATFORM)}.gem"

namespace :build do

  desc "Build #{CoreGem} into the pkg directory"
  task :core => build_deps do
    sh "gem build #{CORE_GEMSPEC.name}.gemspec"
    sh 'mv *.gem pkg/'
  end

  if Concurrent.allow_c_extensions?

    desc "Build #{ExtensionGem}.gem into the pkg directory"
    task :ext => [:clean] do
      sh "gem build #{EXT_GEMSPEC.name}.gemspec"
      sh 'mv *.gem pkg/'
    end

    desc "Build #{NativeGem} into the pkg directory"
    task :native do
      sh "gem compile pkg/#{ExtensionGem}"
      sh 'mv *.gem pkg/'
    end
  end
end

desc 'Build all gems for this platform'
task :build => build_tasks

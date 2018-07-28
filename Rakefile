#!/usr/bin/env rake

require_relative 'lib/concurrent/version'
require_relative 'lib/concurrent/utility/engine'

core_gemspec = Gem::Specification.load File.join(__dir__, 'concurrent-ruby.gemspec')
ext_gemspec  = Gem::Specification.load File.join(__dir__, 'concurrent-ruby-ext.gemspec')
edge_gemspec = Gem::Specification.load File.join(__dir__, 'concurrent-ruby-edge.gemspec')

require 'rake/javaextensiontask'

Rake::JavaExtensionTask.new('concurrent_ruby', core_gemspec) do |ext|
  ext.ext_dir = 'ext/concurrent-ruby'
  ext.lib_dir = 'lib/concurrent'
end

unless Concurrent.on_jruby?
  require 'rake/extensiontask'

  Rake::ExtensionTask.new('concurrent_ruby_ext', ext_gemspec) do |ext|
    ext.ext_dir        = 'ext/concurrent-ruby-ext'
    ext.lib_dir        = 'lib/concurrent'
    ext.source_pattern = '*.{c,h}'

    ext.cross_compile  = true
    ext.cross_platform = ['x86-mingw32', 'x64-mingw32']
  end
end

require 'rake_compiler_dock'
namespace :repackage do
  desc '- with Windows fat distributions'
  task :all do
    sh 'bundle package'
    RakeCompilerDock.exec 'support/cross_building.sh'
  end
end

require 'rubygems'
require 'rubygems/package_task'

Gem::PackageTask.new(core_gemspec) {} if core_gemspec
Gem::PackageTask.new(ext_gemspec) {} if ext_gemspec && !Concurrent.on_jruby?
Gem::PackageTask.new(edge_gemspec) {} if edge_gemspec

CLEAN.include('lib/concurrent/2.*', 'lib/concurrent/*.jar')

begin
  require 'rspec'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  options = %w[ --color
                --backtrace
                --seed 1
                --format documentation
                --tag ~notravis ]

  namespace :spec do
    desc '- Configured for ci'
    RSpec::Core::RakeTask.new(:ci) do |t|
      t.rspec_opts = [*options].join(' ')
    end

    desc '- test packaged and installed gems instead of local files'
    task :installed => :repackage do
      sh 'gem install pkg/concurrent-ruby-1.1.0.pre1.gem'
      sh 'gem install pkg/concurrent-ruby-ext-1.1.0.pre1.gem'
      sh 'gem install pkg/concurrent-ruby-edge-0.4.0.pre1.gem'
      ENV['NO_PATH'] = 'true'
      sh 'bundle install'
      sh 'bundle exec rake spec:ci'
    end
  end

  desc 'executed in CI'
  task :ci => [:compile, 'spec:ci']

  task :default => [:clobber, :compile, :spec]
rescue LoadError => e
  puts 'RSpec is not installed, skipping test task definitions: ' + e.message
end

begin
  require 'yard'
  require 'md_ruby_eval'
  require_relative 'support/yard_full_types'

  root = File.expand_path File.dirname(__FILE__)

  cmd = lambda do |command|
    puts ">> executing: #{command}"
    puts ">>        in: #{Dir.pwd}"
    system command or raise "#{command} failed"
  end

  yard_doc        = YARD::Rake::YardocTask.new(:yard)
  yard_doc.before = -> do
    Dir.chdir File.join(root, 'doc') do
      cmd.call 'bundle exec md-ruby-eval --auto'
    end
  end

  namespace :yard do

    desc 'Pushes generated documentation to github pages: http://ruby-concurrency.github.io/concurrent-ruby/'
    task :push => [:setup, :yard] do

      message = Dir.chdir(root) do
        `git log -n 1 --oneline`.strip
      end
      puts "Generating commit: #{message}"

      Dir.chdir "#{root}/yardoc" do
        cmd.call "git add -A"
        cmd.call "git commit -m '#{message}'"
        cmd.call 'git push origin gh-pages'
      end

    end

    desc 'Setups second clone in ./yardoc dir for pushing doc to github'
    task :setup do

      unless File.exist? "#{root}/yardoc/.git"
        cmd.call "rm -rf #{root}/yardoc" if File.exist?("#{root}/yardoc")
        Dir.chdir "#{root}" do
          cmd.call 'git clone --single-branch --branch gh-pages git@github.com:ruby-concurrency/concurrent-ruby.git ./yardoc'
        end
      end
      Dir.chdir "#{root}/yardoc" do
        cmd.call 'git fetch origin'
        cmd.call 'git reset --hard origin/gh-pages'
      end

    end

  end
rescue LoadError => e
  puts 'YARD is not installed, skipping documentation task definitions: ' + e.message
end

namespace :release do
  # Depends on environment of @pitr-ch

  mri_version   = '2.4.3'
  jruby_version = 'jruby-9.1.17.0'

  task :build => 'repackage:all'

  task :test do
    old = ENV['RBENV_VERSION']

    ENV['RBENV_VERSION'] = mri_version
    sh 'rbenv version'
    sh 'bundle exec rake spec:installed'

    ENV['RBENV_VERSION'] = jruby_version
    sh 'rbenv version'
    sh 'bundle exec rake spec:installed'

    puts 'Windows build is untested'

    ENV['RBENV_VERSION'] = old
  end

  task :push do
    sh 'git fetch'
    sh 'test $(git show-ref --verify --hash refs/heads/master) = $(git show-ref --verify --hash refs/remotes/github/master)'

    sh "git tag v#{Concurrent::VERSION}"
    sh "git tag edge-v#{Concurrent::EDGE_VERSION}"
    sh "git push github v#{Concurrent::VERSION} edge-v#{Concurrent::EDGE_VERSION}"

    sh "gem push pkg/concurrent-ruby-#{Concurrent::VERSION}.gem"
    sh "gem push pkg/concurrent-ruby-edge-#{Concurrent::EDGE_VERSION}.gem"
    sh "gem push pkg/concurrent-ruby-ext-#{Concurrent::VERSION}.gem"
    sh "gem push pkg/concurrent-ruby-ext-#{Concurrent::VERSION}-x64-mingw32.gem"
    sh "gem push pkg/concurrent-ruby-ext-#{Concurrent::VERSION}-x86-mingw32.gem"
  end

  task :notify do
    puts 'Manually: create a release on GitHub with relevant changelog part'
    puts 'Manually: send email same as release with relevant changelog part'
    puts 'Manually: update documentation'
    puts '  $ bundle exec rake yard:push'
  end
end

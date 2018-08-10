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
    Dir.chdir(__dir__) do
      sh 'bundle package'
      RakeCompilerDock.exec 'support/cross_building.sh'
    end
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
      Dir.chdir(__dir__) do
        sh 'gem install pkg/concurrent-ruby-1.1.0.pre1.gem'
        sh 'gem install pkg/concurrent-ruby-ext-1.1.0.pre1.gem' if Concurrent.on_cruby?
        sh 'gem install pkg/concurrent-ruby-edge-0.4.0.pre1.gem'
        ENV['NO_PATH'] = 'true'
        sh 'bundle install'
        sh 'bundle exec rake spec:ci'
      end
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

  common_yard_options = ['--no-yardopts',
                         '--no-document',
                         '--no-private',
                         '--embed-mixins',
                         '--markup', 'markdown',
                         '--title', 'Concurrent Ruby',
                         '--template', 'default',
                         '--template-path', 'yard-template',
                         '--default-return', 'undocumented',]

  desc 'Generate YARD Documentation (signpost, master)'
  task :yard => ['yard:signpost', 'yard:master']

  namespace :yard do

    desc '- eval markdown files'
    task :eval_md do
      Dir.chdir File.join(__dir__, 'docs-source') do
        sh 'bundle exec md-ruby-eval --auto'
      end
    end

    define_yard_task = -> name do
      desc "- of #{name} into subdir #{name}"
      YARD::Rake::YardocTask.new(name) do |yard|
        yard.options.push(
            '--output-dir', "docs/#{name}",
            *common_yard_options)
        yard.files = ['./lib/**/*.rb',
                      './lib-edge/**/*.rb',
                      './ext/concurrent_ruby_ext/**/*.c',
                      '-',
                      'docs-source/thread_pools.md',
                      'docs-source/promises.out.md',
                      'README.md',
                      'LICENSE.txt',
                      'CHANGELOG.md']
      end
      Rake::Task[name].prerequisites.push 'yard:eval_md'
    end

    define_yard_task.call(Concurrent::VERSION.split('.')[0..2].join('.'))
    define_yard_task.call('master')

    desc "- signpost for versions"
    YARD::Rake::YardocTask.new(:signpost) do |yard|
      yard.options.push(
          '--output-dir', 'docs',
          '--main', 'docs-source/signpost.md',
          *common_yard_options)
      yard.files = ['no-lib']
    end
  end

  namespace :spec do
    desc '- ensure that generated documentation is matching the source code'
    task :docs_uptodate do
      Dir.chdir(__dir__) do
        begin
          FileUtils.cp_r 'docs', 'docs-copy', verbose: true
          Rake::Task[:yard].invoke
          sh 'diff -r docs/ docs-copy/'
        ensure
          FileUtils.rm_rf 'docs-copy', verbose: true
        end
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
    Dir.chdir(__dir__) do
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
  end

  task :push do
    Dir.chdir(__dir__) do
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
  end

  task :notify do
    puts 'Manually: create a release on GitHub with relevant changelog part'
    puts 'Manually: send email same as release with relevant changelog part'
    puts 'Manually: update documentation'
    puts '  $ bundle exec rake yard:push'
  end
end

$:.push File.join(File.dirname(__FILE__), 'lib')
$:.push File.join(File.dirname(__FILE__), 'tasks/support')

require 'bundler/gem_tasks'
require 'rspec'
require 'rspec/core/rake_task'
require 'rake/clean'

host_os = RbConfig::CONFIG['host_os']
ruby_name = RbConfig::CONFIG['ruby_install_name']

if ruby_name =~ /^ruby$/i && RUBY_VERSION >= '2.0'
  require 'rake/extensiontask'

  CLEAN.include Rake::FileList['**/*.so', '**/*.bundle', '**/*.o', '**/mkmf.log', '**/Makefile']

  spec = Gem::Specification.load('concurrent-ruby.gemspec')
  Rake::ExtensionTask.new('concurrent', spec) do |ext|
    ext.source_pattern = "**/*.{h,c,cpp}"
  end

  desc 'Clean, compile, and build the extension from scratch'
  task :rebuild => [ :clean, :compile ]

  task :irb => [:compile] do
    sh 'irb -r ./lib/rubyconcurrent.bundle'
  end
end

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec)
$:.unshift 'tasks'
Dir.glob('tasks/**/*.rake').each do|rakefile|
  load rakefile
end

RSpec::Core::RakeTask.new(:travis_spec) do |t|
  t.rspec_opts = '--tag ~@not_on_travis'
end

task :default => [:travis_spec]

$:.push File.join(File.dirname(__FILE__), 'lib')
$:.push File.join(File.dirname(__FILE__), 'tasks/support')

require 'bundler/gem_tasks'
require 'rspec'
require 'rspec/core/rake_task'
require 'rake/clean'

def use_extensions?
  RbConfig::CONFIG['ruby_install_name'] =~ /^ruby$/i && RUBY_VERSION >= '2.0'
end

EXTENSION_NAME = 'concurrent_ruby_ext'

if use_extensions?
  require 'rake/extensiontask'

  CLEAN.include Rake::FileList['**/*.so', '**/*.bundle', '**/*.o', '**/mkmf.log', '**/Makefile']

  spec = Gem::Specification.load('concurrent-ruby.gemspec')
  Rake::ExtensionTask.new(EXTENSION_NAME, spec) do |ext|
    ext.source_pattern = "**/*.{h,c,cpp}"
  end

  task :return_dummy_makefile do
    sh "git co ext/#{EXTENSION_NAME}/Makefile"
  end

  desc 'Clean, compile, and build the extension from scratch'
  task :rebuild => [ :clean, :compile, :return_dummy_makefile ]

  task :irb => [:compile] do
    sh "irb -r ./lib/#{EXTENSION_NAME}.bundle"
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

if use_extensions?
  task :default => [:compile, :travis_spec]
else
  task :default => [:travis_spec]
end

require 'rake'
require 'rake/testtask'

task :default => :test

desc "Run tests"
Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.test_files = FileList["test/**/*.rb"]
end

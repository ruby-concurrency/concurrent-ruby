require 'rake'
require 'rake/testtask'

task :default => :test

desc "Run tests"
Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.test_files = FileList["test/**/*.rb"]
end

desc "Run benchmarks"
task :bench do
  exec "ruby -Ilib -Iext test/bench_atomic.rb"
end

if defined?(JRUBY_VERSION)
  require 'ant'

  directory "pkg/classes"

  desc "Clean up build artifacts"
  task :clean do
    rm_rf "pkg/classes"
    rm_rf "lib/refqueue.jar"
  end

  desc "Compile the extension"
  task :compile => "pkg/classes" do |t|
    ant.javac :srcdir => "ext", :destdir => t.prerequisites.first,
      :source => "1.5", :target => "1.5", :debug => true,
      :classpath => "${java.class.path}:${sun.boot.class.path}"
  end

  desc "Build the jar"
  task :jar => :compile do
    ant.jar :basedir => "pkg/classes", :destfile => "lib/atomic_reference.jar", :includes => "**/*.class"
  end

  task :package => :jar
end

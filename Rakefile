# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rake'
require 'rake/testtask'

task :default => :test

desc "Run tests"
Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.libs << "ext"
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
else
  task :package do
    Dir.chdir("ext") do
      # this does essentially the same thing
      # as what RubyGems does
      ruby "extconf.rb"
      sh "make"
    end
  end
end

task :test => :package

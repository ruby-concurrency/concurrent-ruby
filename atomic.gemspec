# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{atomic}
  s.version = "0.0.6"
  s.authors = ["Charles Oliver Nutter", "MenTaLguY"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = "An atomic reference implementation for JRuby and green or GIL-threaded impls"
  s.email = ["headius@headius.com", "mental@rydia.net"]
  s.homepage = "http://github.com/headius/ruby-atomic"
  s.require_paths = ["lib"]
  s.summary = "An atomic reference implementation for JRuby and green or GIL-threaded impls"
  s.test_files = Dir["test/test*.rb"]
  if defined?(JRUBY_VERSION)
    s.files = Dir['{lib,examples,test}/**/*'] + Dir['{*.txt,*.gemspec,Rakefile}']
    s.platform = 'java'
  else
    s.files = Dir['{lib,examples,test,ext}/**/*'] + Dir['{*.txt,*.gemspec,Rakefile}']
    s.extensions = 'ext/extconf.rb'
  end
end

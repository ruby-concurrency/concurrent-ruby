# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{atomic}
  s.version = "0.0.4"
  s.authors = ["Charles Oliver Nutter", "MenTaLguY"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = "An atomic reference implementation for JRuby and green or GIL-threaded impls"
  s.email = ["headius@headius.com", "mental@rydia.net"]
  s.files = Dir['{lib,examples,test,ext}/**/*'] + Dir['{*.txt,*.gemspec,Rakefile}']
  s.homepage = "http://github.com/headius/ruby-atomic"
  s.require_paths = ["lib"]
  s.summary = "An atomic reference implementation for JRuby and green or GIL-threaded impls"
  s.test_files = Dir["test/test*.rb"]
  s.extensions = 'ext/extconf.rb'
end

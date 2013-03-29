# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{atomic}
  s.version = "1.0.2"
  s.authors = ["Charles Oliver Nutter", "MenTaLguY"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = "An atomic reference implementation for JRuby, Rubinius, and MRI"
  s.email = ["headius@headius.com", "mental@rydia.net"]
  s.homepage = "http://github.com/headius/ruby-atomic"
  s.require_paths = ["lib"]
  s.summary = "An atomic reference implementation for JRuby, Rubinius, and MRI"
  s.test_files = Dir["test/test*.rb"]
  if defined?(JRUBY_VERSION)
    s.files = Dir['lib/atomic_reference.jar']
    s.platform = 'java'
  else
    s.extensions = 'ext/extconf.rb'
  end
  s.files += `git ls-files`.lines.map(&:chomp)
end

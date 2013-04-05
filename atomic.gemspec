# -*- encoding: utf-8 -*-

# Update these to get proper version and commit history
new_version = "1.1.2"
old_version = "1.1.1"

Gem::Specification.new do |s|
  s.name = %q{atomic}
  s.version = new_version
  s.authors = ["Charles Oliver Nutter", "MenTaLguY", "Sokolov Yura"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = <<EOS
Changes in version #{new_version}:

#{`git log --oneline #{old_version}...#{new_version}`}
#{`kramdown README.md`}
EOS
puts s.description
  s.email = ["headius@headius.com", "mental@rydia.net", "funny.falcon@gmail.com"]
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

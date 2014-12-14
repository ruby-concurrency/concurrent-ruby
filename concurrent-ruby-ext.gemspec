$:.push File.join(File.dirname(__FILE__), 'lib')

require 'concurrent/version'

Gem::Specification.new do |s|
  s.name        = 'concurrent-ruby-ext'
  s.version     = Concurrent::EXT_VERSION
  s.platform    = Gem::Platform::RUBY
  s.author      = "Jerry D'Antonio"
  s.email       = 'jerry.dantonio@gmail.com'
  s.homepage    = 'http://www.concurrent-ruby.com'
  s.summary     = 'C extensions to optimize concurrent-ruby under MRI.'
  s.license     = 'MIT'
  s.date        = Time.now.strftime('%Y-%m-%d')

  s.description = <<-EOF
    Modern concurrency tools including agents, futures, promises, thread pools, actors, supervisors, and more.
    Inspired by Erlang, Clojure, Go, JavaScript, actors, and classic concurrency patterns.
  EOF

  s.files            = Dir['ext/**/*.{h,c,cpp}']
  s.files           += [
    'lib/concurrent/atomic_reference/concurrent_update_error.rb',
    'lib/concurrent/atomic_reference/direct_update.rb',
    'lib/concurrent/atomic_reference/numeric_cas_wrapper.rb',
  ]
  s.extra_rdoc_files = Dir['README*', 'LICENSE*', 'CHANGELOG*']
  s.require_paths    = ['lib']
  s.extensions       = 'ext/concurrent_ruby_ext/extconf.rb'

  s.required_ruby_version = '>= 1.9.3'

  s.add_runtime_dependency 'concurrent-ruby', '~> 0.8.0.pre1'
end

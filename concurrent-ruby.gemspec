$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'concurrent/version'

Gem::Specification.new do |s|
  s.name        = 'concurrent-ruby'
  s.version     = Concurrent::VERSION
  s.platform    = Gem::Platform::RUBY
  s.author      = "Jerry D'Antonio"
  s.email       = 'jerry.dantonio@gmail.com'
  s.homepage    = 'https://github.com/jdantonio/concurrent-ruby/'
  s.summary     = 'Erlang, Clojure, and Go inspired concurrent programming tools for Ruby.'
  s.license     = 'MIT'
  s.date        = Time.now.strftime('%Y-%m-%d')

  s.description = <<-EOF
    A gem for adding Erlang, Clojure, and Go inspired concurrent programming tools to Ruby.
  EOF

  s.files            = Dir['README*', 'LICENSE*', 'CHANGELOG*']
  s.files           += Dir['{lib,md,spec}/**/*']
  s.test_files       = Dir['{spec}/**/*']
  s.extra_rdoc_files = ['README.md']
  s.extra_rdoc_files = Dir['README*', 'LICENSE*', 'CHANGELOG*']
  s.require_paths    = ['lib']

  s.required_ruby_version = '>= 1.9.2'

  s.add_dependency 'functional-ruby', '~> 0.7.0'

  s.add_development_dependency 'bundler'
end

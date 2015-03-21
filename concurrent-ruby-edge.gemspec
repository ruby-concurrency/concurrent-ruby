$:.push File.join(File.dirname(__FILE__), 'lib')

require 'concurrent/version'
require 'concurrent/edge/version'

Gem::Specification.new do |s|
  s.name        = 'concurrent-ruby-edge'
  s.version     = Concurrent::Edge::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jerry D'Antonio", 'The Ruby Concurrency Team']
  s.email       = ['jerry.dantonio@gmail.com', 'concurrent-ruby@googlegroups.com']
  s.homepage    = 'http://www.concurrent-ruby.com'
  s.summary     = 'Experimental features and additions to the concurrent-ruby gem. Minimally tested and documented.'
  s.license     = 'MIT'
  s.date        = Time.now.strftime('%Y-%m-%d')

  s.description = <<-EOF
    Experimental features and additions to the concurrent-ruby gem.
    Minimally tested and documented.
    Please see http://concurrent-ruby.com for more information.
  EOF

  s.files            = Dir['lib/concurrent/edge.rb', 'lib/concurrent/edge/**/*.rb']
  s.files           += Dir['lib/concurrent/actor.rb', 'lib/concurrent/actor/**/*.rb']
  s.files           += Dir['lib/concurrent/channel.rb', 'lib/concurrent/channel/**/*.rb']
  s.extra_rdoc_files = Dir['README*', 'LICENSE*']
  s.require_paths    = ['lib']

  s.required_ruby_version = '>= 1.9.3'

  s.add_runtime_dependency 'concurrent-ruby', "~> #{Concurrent::VERSION}"
end

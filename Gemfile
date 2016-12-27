source 'https://rubygems.org'

gemspec name: 'concurrent-ruby'
gemspec name: 'concurrent-ruby-edge'

group :development do
  gem 'rake', '~> 10.0'
  gem 'rake-compiler', '~> 0.9.5'
  gem 'rake-compiler-dock', '~> 0.4.3'
  gem 'gem-compiler', '~> 0.3.0'
  gem 'benchmark-ips', '~> 2.7'

  # documentation
  gem 'countloc', '~> 0.4.0', :platforms => :mri, :require => false
  gem 'yard', '~> 0.8.0', :require => false
  # TODO (pitr-ch 15-Oct-2016): does not work on 1.9.3 anymore
  # TODO remove, reports private classes as undocumented
  gem 'inch', '~> 0.7.0', :platforms => :mri, :require => false
  gem 'redcarpet', '~> 3.3', platforms: :mri # understands github markdown
  gem 'md-ruby-eval'
end

group :testing do
  gem 'rspec', '~> 3.3.0'
  gem 'timecop', '~> 0.7.4'
end

# made opt-in since it will not install on jruby 1.7
if ENV['COVERAGE']
  group :coverage do
    gem 'simplecov', '~> 0.10.0', :require => false
    gem 'coveralls', '~> 0.8.2', :require => false
  end
end

group :benchmarks do
  gem 'bench9000'
end

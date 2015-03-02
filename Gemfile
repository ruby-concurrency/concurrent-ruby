source 'https://rubygems.org'

gemspec name: 'concurrent-ruby'

group :development do
  gem 'rake', '~> 10.3.2'
  gem 'rake-compiler', '~> 0.9.5'
  gem 'gem-compiler', '~> 0.3.0'
end

group :testing do
  gem 'rspec', '~> 3.2.0'
  gem 'simplecov', '~> 0.9.2', :require => false
  gem 'coveralls', '~> 0.7.11', :require => false
  gem 'timecop', '~> 0.7.3'
end

group :documentation do
  gem 'countloc', '~> 0.4.0', :platforms => :mri, :require => false
  gem 'yard', '~> 0.8.7.6', :require => false
  gem 'inch', '~> 0.5.10', :platforms => :mri, :require => false
  gem 'redcarpet', '~> 3.2.2', platforms: :mri # understands github markdown
end

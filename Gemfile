source 'https://rubygems.org'

gemspec

gem 'rake', '~> 10.3.2'
gem 'rake-compiler', '~> 0.9.2'

group :testing do
  gem 'rspec', '~> 2.14.1'
  gem 'simplecov', '~> 0.8.2', :require => false
  gem 'coveralls', '~> 0.7.0', :require => false
  gem 'timecop', '~> 0.7.1'
end

group :documentation do
  gem 'countloc', '~> 0.4.0', :platforms => :mri, :require => false
  gem 'yard', '~> 0.8.7.4', :require => false
  gem 'inch', '~> 0.4.1', :platforms => :mri, :require => false
  gem 'redcarpet', '~> 3.1.2', platforms: :mri # understands github markdown
end

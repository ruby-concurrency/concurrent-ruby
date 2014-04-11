require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  project_name 'concurrent-ruby'
  add_filter '/coverage/'
  add_filter '/doc/'
  add_filter '/pkg/'
  add_filter '/spec/'
  add_filter '/tasks/'
end

require 'concurrent'

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
  end

  config.before(:each) do
    reset_gem_configuration
  end

  config.after(:each) do
    Thread.list.each do |thread|
      thread.kill unless thread == Thread.current
    end
  end

  config.after(:suite) do
  end
end

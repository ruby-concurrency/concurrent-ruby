if ENV['COVERAGE']
  require 'simplecov'
  require 'coveralls'

  if ENV['TRAVIS']
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
        SimpleCov::Formatter::HTMLFormatter,
        Coveralls::SimpleCov::Formatter
    ]
  else
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  end

  SimpleCov.start do
    project_name 'concurrent-ruby'
    add_filter '/build-tests/'
    add_filter '/examples/'
    add_filter '/spec/'
  end
end

require 'concurrent'
require 'concurrent-edge'

Concurrent.use_simple_logger Logger::FATAL

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  #config.raise_errors_for_deprecations!
  config.filter_run_excluding stress: true
  config.order = 'random'
end

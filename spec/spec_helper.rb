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

require_relative 'support/example_group_extensions'
require_relative 'support/less_than_or_equal_to_matcher'
require_relative 'support/threadsafe_test'

RSpec.configure do |config|
  #config.raise_errors_for_deprecations!
  config.filter_run_excluding stress: true
  config.order = 'random'
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = 'spec/examples.txt'
end

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
require 'rspec'

Concurrent.use_simple_logger Logger::FATAL

require_relative 'support/example_group_extensions'
require_relative 'support/threadsafe_test'

RSpec.configure do |config|
  #config.raise_errors_for_deprecations!
  config.filter_run_excluding stress: true
  config.order = 'random'
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = 'spec/examples.txt'

  config.include Concurrent::TestHelpers
  config.extend Concurrent::TestHelpers

  config.before :each do
    expect(!defined?(@created_threads) || @created_threads.nil? || @created_threads.empty?).to be_truthy
  end

  config.after :each do
    while defined?(@created_threads) && @created_threads && (thread = (@created_threads.pop(true) rescue nil))
      thread.kill
      thread_join = thread.join(0.25)
      expect(thread_join).not_to be_nil, thread.inspect
    end
  end
end

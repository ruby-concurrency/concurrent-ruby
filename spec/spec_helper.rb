require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  project_name 'concurrent-ruby'
  add_filter '/build-tests/'
  add_filter '/coverage/'
  add_filter '/doc/'
  add_filter '/examples/'
  add_filter '/pkg/'
  add_filter '/spec/'
  add_filter '/tasks/'
  add_filter '/yard-template/'
  add_filter '/yardoc/'
end

require 'concurrent'

logger                          = Logger.new($stderr)
logger.level                    = Logger::WARN
Concurrent.configuration.logger = lambda do |level, progname, message = nil, &block|
  logger.add level, message, progname, &block
end

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  #config.raise_errors_for_deprecations!
  config.order = 'random'

  config.before(:each) do
    #TODO: Better configuration management in individual test suites
    reset_gem_configuration
  end

  config.after(:each) do
    #TODO: Better thread management in individual test suites
    kill_rogue_threads(false)
  end
end

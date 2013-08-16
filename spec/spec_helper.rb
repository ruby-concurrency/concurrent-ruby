require 'simplecov'
SimpleCov.start do
  project_name 'concurrent-ruby'
  add_filter '/md/'
  add_filter '/pkg/'
  add_filter '/spec/'
  add_filter '/tasks/'
end

require 'eventmachine'

require 'concurrent'
require 'concurrent/functions'

require 'rbconfig'

def mri?
  RbConfig::CONFIG['ruby_install_name'] =~ /^ruby$/i
end

def jruby?
  RbConfig::CONFIG['ruby_install_name'] =~ /^jruby$/i
end

def rbx?
  RbConfig::CONFIG['ruby_install_name'] =~ /^rbx$/i
end

def windows?
  (RbConfig::CONFIG['host_os'] =~ /win32/i) || (RbConfig::CONFIG['host_os'] =~ /mingw32/i)
end

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
  end

  config.before(:each) do
  end

  config.after(:each) do
  end

end

require 'eventmachine'

require 'concurrent'
require 'concurrent/functions'

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
  end

  config.before(:each) do
    @orig_stdout = $stdout
    $stdout = StringIO.new 
  end

  config.after(:each) do
    $stdout = @orig_stdout
  end

end

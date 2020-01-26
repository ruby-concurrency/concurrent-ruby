
lib = File.expand_path '../../../lib/concurrent-ruby/'
$LOAD_PATH.push lib unless $LOAD_PATH.include? lib

require 'concurrent-ruby'

# the test relies on replicating that Minitest messed up the AtExit handling
Concurrent.disable_at_exit_handlers!
pool = Concurrent::CachedThreadPool.new
pool.post do
  sleep # sleep indefinitely
end

# the process main thread should quit out which should kill the daemon CachedThreadPool


lib = File.expand_path '../../../lib/concurrent-ruby/'
$LOAD_PATH.push lib unless $LOAD_PATH.include? lib

require 'concurrent-ruby'

pool = Concurrent::CachedThreadPool.new
pool.post do
  sleep # sleep indefinitely
end

# the process main thread should quit out which should kill the daemon CachedThreadPool

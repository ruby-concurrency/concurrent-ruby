$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)

require 'minitest/autorun'
require 'concurrent'
class CachedThreadPoolTest < Minitest::Test

  def test_cached_thread_pool_does_not_impede_shutdown
    pool = Concurrent::CachedThreadPool.new
    pool.post do
      sleep
    end

  end
end
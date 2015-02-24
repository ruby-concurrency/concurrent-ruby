# monkey-patch Array and Hash
#
# `require 'concurrent/parallel/core_ext'` to enable

require 'concurrent/parallel'

module Enumerable
  def parallel(opts = {})
    Concurrent::Parallel.new(self, opts)
  end

  def serial
    self
  end
end

# monkey-patch Array and Hash
#
# `require 'concurrent/parallel/core_ext'` to enable

require 'concurrent/parallel'

module Enumerable

  def parallel_map(opts = {}, &block)
    Concurrent::Parallel.map(self, opts, &block)
  end
end

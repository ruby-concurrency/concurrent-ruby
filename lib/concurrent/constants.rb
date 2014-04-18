Infinity = 1/0.0 unless defined?(Infinity)
NaN = 0/0.0 unless defined?(NaN)

module Concurrent

  NO_VALUE = NULL = Object.new.freeze

  if RUBY_PLATFORM == 'java'

    MAX_INT = java.lang.Integer::MAX_VALUE
    MAX_LONG = java.lang.Long::MAX_VALUE

  elsif ! defined? Concurrent::MAX_INT

    MAX_INT = MAX_LONG = (2**(0.size * 8 -2) -1)
  end
end

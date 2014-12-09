module Concurrent

  # @!visibility private
  def self.safe_require_java_extensions
    require 'concurrent_ruby_ext' if RUBY_PLATFORM == 'java'
  rescue LoadError
    #warn 'Attempted to load Java extensions on unsupported platform. Continuing with pure-Ruby.'
  end
end

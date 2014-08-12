module Concurrent

  # @!visibility private
  def self.allow_c_extensions?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
  end

  # @!visibility private
  def self.allow_c_native_class?(clazz)
    allow_c_extensions? && Concurrent.const_defined?(clazz)
  rescue
    false
  end

  # @!visibility private
  def self.safe_require_c_extensions
    require 'concurrent_ruby_ext' if allow_c_extensions?
  rescue LoadError
    #warn 'Attempted to load C extensions on unsupported platform. Continuing with pure-Ruby.'
  end

  # @!visibility private
  def self.safe_require_java_extensions
    require 'concurrent_ruby_ext' if RUBY_PLATFORM == 'java'
  rescue LoadError
    #warn 'Attempted to load Java extensions on unsupported platform. Continuing with pure-Ruby.'
  end
end

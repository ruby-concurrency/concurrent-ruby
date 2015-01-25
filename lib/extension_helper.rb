module Concurrent

  @@c_ext_loaded ||= false
  @@java_ext_loaded ||= false

  # @!visibility private
  def self.allow_c_extensions?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
  end

  # @!visibility private
  def self.jruby?
    RUBY_PLATFORM == 'java'
  end

  if allow_c_extensions? && !@@c_ext_loaded
    begin
      require 'concurrent/extension'
      @@c_ext_loaded = true
    rescue LoadError
      # may be a Windows cross-compiled native gem
      begin
        require "concurrent/#{RUBY_VERSION[0..2]}/extension"
        @@c_ext_loaded = true
      rescue LoadError
        warn 'Performance on MRI may be improved with the concurrent-ruby-ext gem. Please see http://concurrent-ruby.com'
      end
    end
  elsif jruby? && !@@java_ext_loaded
    begin
      require 'concurrent_ruby_ext'
      @@java_ext_loaded = true
    rescue LoadError
      warn 'Performance on JRuby may be improved by installing the pre-compiled Java extensions. Please see http://concurrent-ruby.com'
    end
  end
end

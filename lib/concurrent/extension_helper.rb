require 'concurrent/utility/engine'

module Concurrent

  class AbstractSynchronizedObject # FIXME has to be present before Java extensions are loaded
  end

  @@c_ext_loaded ||= false
  @@java_ext_loaded ||= false

  # @!visibility private
  def self.allow_c_extensions?
    on_cruby?
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
  elsif on_jruby? && !@@java_ext_loaded
    begin
      require 'concurrent_ruby_ext'
      @@java_ext_loaded = true
    rescue LoadError
      warn 'Performance on JRuby may be improved by installing the pre-compiled Java extensions. Please see http://concurrent-ruby.com'
    end
  end
end

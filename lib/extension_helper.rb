require 'rbconfig'

module Concurrent
  def self.use_c_extensions?
    host_os = RbConfig::CONFIG['host_os']
    ruby_name = RbConfig::CONFIG['ruby_install_name']
    (ruby_name =~ /^ruby$/i || host_os =~ /mswin32/i || host_os =~ /mingw32/i) #&& RUBY_VERSION >= '2.0'
  end
end

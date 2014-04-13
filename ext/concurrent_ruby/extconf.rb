require 'rbconfig'

EXTENSION_NAME = 'concurrent_ruby'

def real_build
  dir_config(EXTENSION_NAME)
  create_makefile(EXTENSION_NAME)
end

def fake_build
  # http://yorickpeterse.com/articles/hacking-extconf-rb/
  File.touch(File.join(Dir.pwd, EXTENSION_NAME + '.' + RbConfig::CONFIG['DLEXT']))
  $makefile_created = true
end

host_os = RbConfig::CONFIG['host_os']
ruby_name = RbConfig::CONFIG['ruby_install_name']

if RUBY_PLATFORM == 'java'
  puts 'JRuby detected. Pure Java optimizations will be used.'
elsif host_os =~ /win32/i || host_os =~ /mingw32/i
  puts 'C extensions for this gem not supported on Windows. 100% pure Ruby classes will be installed.'
elsif ruby_name =~ /^rbx$/i
  puts 'C extensions for this gem not supported on Rubinius. 100% pure Ruby classes will be installed.'
elsif ruby_name =~ /^ruby$/i
  if RUBY_VERSION < '2.0'
    puts 'C extensions for this gem are only supported on MRI/CRuby 2.0 and above. 100% pure Ruby classes will be installed.'
  else
    require 'mkmf'
    if ! have_library('pthread')
      puts 'The pthreads library is not detected. 100% pure Ruby classes will be installed.'
      fake_build
    else
      real_build
    end
  end
else
  puts 'Unknown Ruby interpreter detected. 100% pure Ruby classes will be installed.'
end

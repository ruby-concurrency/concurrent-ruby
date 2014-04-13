require 'rbconfig'

EXTENSION_NAME = 'concurrent_ruby_ext'

def use_extensions?
  RbConfig::CONFIG['ruby_install_name'] =~ /^ruby$/i && RUBY_VERSION >= '2.0'
end

def real_build
  dir_config(EXTENSION_NAME)
  create_makefile(EXTENSION_NAME)
end

def fake_build
  # http://yorickpeterse.com/articles/hacking-extconf-rb/
  File.touch(File.join(Dir.pwd, EXTENSION_NAME + '.' + RbConfig::CONFIG['DLEXT']))
  $makefile_created = true
end

if RUBY_PLATFORM == 'java'
  puts 'JRuby detected. Pure Java optimizations will be used.'
elsif ! use_extensions?
  puts 'C optimizations are only supported on MRI 2.0 and above.'
else
  begin
    require 'mkmf'
    if ! have_library('pthread')
      puts 'The pthreads library is not detected. C optimizations will not be used.'
      fake_build
    else
      real_build
    end
  rescue
    puts 'C optimizations are not supported on this version of Ruby.'
  end
end

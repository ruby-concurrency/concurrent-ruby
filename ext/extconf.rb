require 'fileutils'

$:.push File.join(File.dirname(__FILE__), '../lib')
require 'extension_helper'

EXTENSION_NAME = 'concurrent_cruby'

if defined?(JRUBY_VERSION)
  puts 'JRuby detected. Pure Java optimizations will be used.'
elsif ! Concurrent.use_c_extensions?
  puts 'C optimizations are only supported on MRI 2.0 and above.'
else

  def fake_build
    # http://yorickpeterse.com/articles/hacking-extconf-rb/
    FileUtils.touch(File.join(Dir.pwd, EXTENSION_NAME + '.' + RbConfig::CONFIG['DLEXT']))
    $makefile_created = true
  end

  begin

    require 'mkmf'
    dir_config(EXTENSION_NAME)

    have_header "libkern/OSAtomic.h"

    def compiler_is_gcc
      if CONFIG["GCC"] && CONFIG["GCC"] != ""
        return true
      elsif ( # This could stand to be more generic...  but I am afraid.
             CONFIG["CC"] =~ /\bgcc\b/
            )
        return true
      end
      return false
    end

    if compiler_is_gcc
      case CONFIG["arch"]
      when /mswin32|mingw|solaris/
        $CFLAGS += " -march=native"
      when 'i686-linux'
        $CFLAGS += " -march=i686"
      end
    end

    try_run(<<CODE,$CFLAGS) && ($defs << '-DHAVE_GCC_CAS')
int main() {
  int i = 1;
  __sync_bool_compare_and_swap(&i, 1, 4);
  return (i != 4);
}
CODE

    create_makefile(EXTENSION_NAME)
  rescue
    puts 'C optimizations are not supported on this version of Ruby.'
    fake_build
  end
end

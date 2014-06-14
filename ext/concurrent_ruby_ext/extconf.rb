require 'fileutils'

$:.push File.join(File.dirname(__FILE__), '../../lib')
require 'extension_helper'

EXTENSION_NAME = 'concurrent_ruby_ext'

def create_dummy_makefile
  File.open('Makefile', 'w') do |f|
    f.puts 'all:'
    f.puts 'install:'
  end
end

if defined?(JRUBY_VERSION) || ! Concurrent.use_c_extensions? 
  create_dummy_makefile
  warn 'C optimizations are not supported on this version of Ruby.'
else
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
    create_dummy_makefile
    warn 'C optimizations cannot be compiled on this version of Ruby.'
  end
end

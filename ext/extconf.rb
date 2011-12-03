require 'mkmf'
extension_name = 'atomic_reference'
dir_config(extension_name)

case CONFIG["arch"]
when /mswin32|mingw/
    $CFLAGS += " -march=i686"
end

create_makefile(extension_name)

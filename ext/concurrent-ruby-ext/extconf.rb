require 'mkmf'

unless RUBY_ENGINE == 'ruby'
  File.write('Makefile', dummy_makefile($srcdir).join(''))
  exit
end

extension_name = 'concurrent_ruby_ext'

dir_config(extension_name)

# ruby/atomic.h only became a public extension header in Ruby 3.0.
have_header('ruby/atomic.h')

create_makefile File.join('concurrent', extension_name)

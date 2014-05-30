begin
  # force fallback impl with FORCE_ATOMIC_FALLBACK=1
  if /[^0fF]/ =~ ENV['FORCE_ATOMIC_FALLBACK']
    ruby_engine = 'fallback'
  else
    ruby_engine = defined?(RUBY_ENGINE)? RUBY_ENGINE : 'ruby'
  end

  require "concurrent/atomic_reference/#{ruby_engine}"
rescue LoadError
  warn "#{__FILE__}:#{__LINE__}: unsupported Ruby engine `#{RUBY_ENGINE}', using less-efficient Atomic impl"
  require 'concurrent/atomic_reference/fallback'
end

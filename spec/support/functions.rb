require 'rbconfig'

def delta(v1, v2)
  if block_given?
    v1 = yield(v1)
    v2 = yield(v2)
  end
  return (v1 - v2).abs
end

def mri?
  RbConfig::CONFIG['ruby_install_name']=~ /^ruby$/i 
end

def jruby?
  RbConfig::CONFIG['ruby_install_name']=~ /^jruby$/i 
end

def rbx?
  RbConfig::CONFIG['ruby_install_name']=~ /^rbx$/i 
end

def use_extensions?
  RbConfig::CONFIG['ruby_install_name'] =~ /^ruby$/i && RUBY_VERSION >= '2.0'
end

def reset_gem_configuration
  Concurrent.instance_variable_set(:@configuration, Concurrent::Configuration.new)
end

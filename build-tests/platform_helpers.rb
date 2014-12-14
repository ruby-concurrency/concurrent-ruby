require 'rbconfig'

def mri?(engine = RUBY_ENGINE)
  engine == 'ruby'
end

def jruby?(engine = RUBY_ENGINE)
  engine == 'jruby'
end

def rbx?(engine = RUBY_ENGINE)
  engine == 'rbx'
end

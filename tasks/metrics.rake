unless defined?(JRUBY_VERSION)

  desc 'Display LOC (lines of code) report'
  task :loc do
    puts `countloc -r lib`
  end
end

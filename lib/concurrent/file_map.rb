module Concurrent

  git_files      = `git ls-files`.split("\n")
  all_lib_files  = Dir['lib/concurrent/**/*.rb'] & git_files
  edge_lib_files = Dir['lib/concurrent/actor.rb',
                       'lib/concurrent/actor/**/*.rb',
                       'lib/concurrent/channel.rb',
                       'lib/concurrent/channel/**/*.rb',
                       'lib/concurrent/edge/**/*.rb'] & git_files
  core_lib_files = all_lib_files - edge_lib_files

  FILE_MAP = {
      core: core_lib_files + %w(lib/concurrent.rb lib/concurrent_ruby.rb),
      edge: edge_lib_files + %w(lib/concurrent-edge.rb)
  }
end


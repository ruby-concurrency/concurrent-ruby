require 'concurrent'

my_atomic = Concurrent::Atomic.new(0)
my_atomic.update {|v| v + 1}
puts "new value: #{my_atomic.value}"

begin
  my_atomic.try_update {|v| v + 1}
rescue Concurrent::Atomic::ConcurrentUpdateError => cue
  # deal with it (retry, propagate, etc)
end
puts "new value: #{my_atomic.value}"

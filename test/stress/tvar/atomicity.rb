require 'concurrent-ruby'

v1 = Concurrent::TVar.new(0)
v2 = Concurrent::TVar.new(0)

Thread.new do
  loop do
    Concurrent.atomically do
      v1.value += 1
      v2.value += 1
    end
  end
end

loop do
  a, b = Concurrent.atomically {
    a = v1.value
    b = v2.value
    [a, b]
  }
  raise if a != b
  p a

  a, b = Concurrent.atomically {
    b = v2.value
    a = v1.value
    [a, b]
  }
  raise if a != b
  p a
end

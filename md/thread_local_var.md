# Thread Local Variables

A `ThreadLocalVar` is a variable where the value is different for each thread.
Each variable may have a default value, but when you modify the variable only
the current thread will ever see that change.

```ruby
v = ThreadLocalVar.new(14)
v.value #=> 14
v.value = 2
v.value #=> 2
```

```ruby
v = ThreadLocalVar.new(14)

t1 = Thread.new do
  v.value #=> 14
  v.value = 1
  v.value #=> 1
end

t2 = Thread.new do
  v.value #=> 14
  v.value = 2
  v.value #=> 2
end

v.value #=> 14
```

Note that except on JRuby, `ThreadLocalVar` needs to allocate a unique symbol
for each instance. This may lead to a space leak.

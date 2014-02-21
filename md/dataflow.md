# Dataflow

## Example

In this example we'll derive the `dataflow` method.

Consider a naive fibonacci calculator.

```ruby
def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

puts fib(14)
```

We could modify this to use futures.

```ruby
def fib(n)
  if n < 2
    Concurrent::Future.new { n }
  else
    n1 = fib(n - 1).execute
    n2 = fib(n - 2).execute
    Concurrent::Future.new { n1.value + n2.value }
  end
end

f = fib(14)
f.execute
sleep(0.5)
puts f.value
```

One of the drawbacks of this approach is that all the futures start, and then
most of them immediately block on their dependencies. We know that there's no
point executing those futures until their dependencies are ready, so let's
not execute each future until all their dependencies are ready.

To do this we'll create an object that counts the number of times it observes a
future finishing before it does something - and for us that something will be to
execute the next future.

```ruby
class CountingObserver

  def initialize(count, &block)
    @count = count
    @block = block
  end

  def update(time, value, reason)
    @count -= 1

    if @count <= 0
      @block.call()
    end
  end

end

def fib(n)
  if n < 2
    Concurrent::Future.new { n }.execute
  else
    n1 = fib(n - 1)
    n2 = fib(n - 2)

    result = Concurrent::Future.new { n1.value + n2.value }

    barrier = CountingObserver.new(2) { result.execute }
    n1.add_observer barrier
    n2.add_observer barrier

    n1.execute
    n2.execute

    result
  end
end
```

We can wrap this up in a dataflow utility.

```ruby
f = fib(14)
sleep(0.5)
puts f.value

def dataflow(*inputs, &block)
  result = Concurrent::Future.new(&block)

  if inputs.empty?
    result.execute
  else
    barrier = CountingObserver.new(inputs.size) { result.execute }

    inputs.each do |input|
      input.add_observer barrier
    end
  end

  result
end

def fib(n)
  if n < 2
    dataflow { n }
  else
    n1 = fib(n - 1)
    n2 = fib(n - 2)
    dataflow(n1, n2) { n1.value + n2.value }
  end
end

f = fib(14)
sleep(0.5)
puts f.value
```

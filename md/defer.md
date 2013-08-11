# I Can't Think of a Movie or Music Reference for Defer

In the pantheon of concurrency objects a `Defer` sits somewhere between `Future` and `Promise`.
Inspired by [EventMachine's *defer* method](https://github.com/eventmachine/eventmachine/wiki/EM::Deferrable-and-EM.defer),
a `Defer` can be considered a non-blocking `Future` or a simplified, non-blocking `Promise`. Defers run on the global thread pool.

Unlike `Future` and `Promise` a defer is non-blocking. The deferred *operation* is performed on another
thread. If the *operation* is successful an optional *callback* is called on the same thread as the *operation*.
The result of the *operation* is passed to the *callbacl*. If the *operation* fails (by raising an exception)
then an optional *errorback* (error callback) is called on the same thread as the *operation*. The raised
exception is passed to the *errorback*. The calling thread is never aware of the result of the *operation*.
This approach fits much more cleanly within an
[event-driven](http://en.wikipedia.org/wiki/Event-driven_programming) application.

The operation of a `Defer` can easily be simulated using either `Future` or `Promise` and traditional branching
(if/then/else) logic. This approach works but it is more verbose and partitions the work across two threads.
Whenever you find yourself checking the result of a `Future` or a `Promise` then branching based on the result,
consider a `Defer` instead.

For programmer convenience there are two syntaxes for creating and running a `Defer`. One is idiomatic of Ruby
and uses chained method calls. The other is more isiomatic of [functional programming](http://en.wikipedia.org/wiki/Concurrentprogramming)
and passes one or more `proc` objects as arguments. Do not mix syntaxes on a single `Defer` invocation.

## Examples

A simple `Defer` using idiomatic Ruby syntax:

```ruby
require 'concurrent'

deferred = Concurrent::Defer.new{ puts 'w00t!' }
# when using idiomatic syntax the #go method must be called
deferred.go
sleep(0.1)

#=> 'w00t!'
```

A simple `Defer` using functional programming syntax:

```ruby
operation = proc{ puts 'w00t!' }
Concurrent::Defer.new(operation) # NOTE: a call to #go is unnecessary
sleep(0.1)

#=> 'w00t!'

defer(operation)
sleep(0.1)

#=> 'w00t!'
```

Adding a *callback*:

```ruby
Concurrent::Defer.new{ "Jerry D'Antonio" }.
                  then{|result| puts "Hello, #{result}!" }.
                  go

#=> Hello, Jerry D'Antonio!

operation = proc{ "Jerry D'Antonio" }
callback = proc{|result| puts "Hello, #{result}!" }
defer(operation, callback, nil)
sleep(0.1)

#=> Hello, Jerry D'Antonio!
```

Adding an *errorback*:

```ruby
Concurrent::Defer.new{ raise StandardError.new('Boom!') }.
                  rescue{|ex| puts ex.message }.
                  go
sleep(0.1)

#=> "Boom!"

operation = proc{ raise StandardError.new('Boom!') }
errorback = proc{|ex| puts ex.message }
defer(operation, nil, errorback)

#=> "Boom!"
```

Putting it all together:

```ruby
Concurrent::Defer.new{ "Jerry D'Antonio" }.
                  then{|result| puts "Hello, #{result}!" }.
                  rescue{|ex| puts ex.message }.
                  go

#=> Hello, Jerry D'Antonio!

operation = proc{ raise StandardError.new('Boom!') }
callback  = proc{|result| puts result }
errorback = proc{|ex| puts ex.message }
defer(operation, callback, errorback)
sleep(0.1)

#=> "Boom!"
```

Crossing the streams:

```ruby
operation = proc{ true }
callback = proc{|result| puts result }
errorback = proc{|ex| puts ex.message }

Concurrent::Defer.new(operation, nil, nil){ false }
#=> ArgumentError: two operations given

defer(nil, callback, errorback)
# => ArgumentError: no operation given

Concurrent::Defer.new.go
# => ArgumentError: no operation given

defer(nil, nil, nil)
# => ArgumentError: no operation given

Concurrent::Defer.new(operation, nil, nil).
                  then{|result| puts result }.
                  go
#=> Concurrent::IllegalMethodCallError: the defer is already running

defer(callback, nil, nil).then{|result| puts result }
#=> Concurrent::IllegalMethodCallError: the defer is already running

Concurrent::Defer.new{ true }.
                  then{|result| puts "Boom!" }.
                  then{|result| puts "Bam!" }.
                  go
#=> Concurrent::IllegalMethodCallError: a callback has already been provided

Concurrent::Defer.new{ raise StandardError }.
                  rescue{|ex| puts "Boom!" }.
                  rescue{|ex| puts "Bam!" }.
                  go
#=> Concurrent::IllegalMethodCallError: a errorback has already been provided
```

## Copyright

*Concurrent Ruby* is Copyright &copy; 2013 [Jerry D'Antonio](https://twitter.com/jerrydantonio).
It is free software and may be redistributed under the terms specified in the LICENSE file.

## License

Released under the MIT license.

http://www.opensource.org/licenses/mit-license.php  

> Permission is hereby granted, free of charge, to any person obtaining a copy  
> of this software and associated documentation files (the "Software"), to deal  
> in the Software without restriction, including without limitation the rights  
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
> copies of the Software, and to permit persons to whom the Software is  
> furnished to do so, subject to the following conditions:  
> 
> The above copyright notice and this permission notice shall be included in  
> all copies or substantial portions of the Software.  
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN  
> THE SOFTWARE.  

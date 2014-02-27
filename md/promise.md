# Promises, Promises...

A promise is the most powerful and versatile of the concurrency objects in this library.
Promises are inspired by the JavaScript [Promises/A](http://wiki.commonjs.org/wiki/Promises/A)
and [Promises/A+](http://promises-aplus.github.io/promises-spec/) specifications.

> A promise represents the eventual value returned from the single completion of an operation.

Promises are similar to futures and share many of the same behaviours. Promises are far more robust,
however. Promises can be chained in a tree structure where each promise may have zero or more children.
Promises are chained using the `then` method. The result of a call to `then` is always another promise.
Promises are resolved asynchronously: parents are guaranteed to be resolved before their children.
`then` takes two parameters: an optional block to be executed upon parent resolution and an optional callable
to be executed upon parent failure.
The result of each promise is passed to each of its children upon resolution.
When a promise is rejected all its children will receive the reason.

Promises have four possible states: *unscheduled*, *pending*, *rejected*, and *fulfilled*.
Promise created using `.new` will be *unscheduled*, to schedule it `execute` method must be called and the
Promise with all its children will be set to *pending*.
When a promise is *pending* will remain in that state until processing is complete.
A completed promise is either *rejected*, indicating that an exception was thrown during processing, or *fulfilled*, indicating it succeeded.
If a promise is *fulfilled* its `value` will be updated to reflect the result of the operation.
If *rejected* the `reason` will be updated with a reference to the thrown exception.
The predicate methods `unscheduled?`, `pending?`, `rejected`, and `fulfilled?`
can be called at any time to obtain the state of the promise, as can the `state` method, which returns a symbol.
Promise created using `.execute` will be *pending*, a Promise created using `.fulfill(value)` will be *fulfilled*
with the passed value and a Promise created using `.reject(reason)` will be *rejected*.

Retrieving the value of a promise is done through the `value` (alias: `deref`) method. Obtaining the value of
a promise is a potentially blocking operation. When a promise is *rejected* a call to `value` will return `nil`
immediately. When a promise is *fulfilled* a call to `value` will immediately return the current value.
When a promise is *pending* a call to `value` will block until the promise is either *rejected* or *fulfilled*.
A *timeout* value can be passed to `value` to limit how long the call will block. If `nil` the call will
block indefinitely. If `0` the call will not block. Any other integer or float value will indicate the
maximum number of seconds to block.

Promises run on the global thread pool.

## Examples

Start by requiring promises

```ruby
require 'concurrent'
```

Then create one

```ruby
p = Promise.execute do
      # do something
      42
    end
```

Promises can be chained using the `then` method. The `then` method
accepts a block, to be executed on fulfillment, and a callable argument to be executed on rejection.
The result of the each promise is passed as the block argument to chained promises.

```ruby
p = Concurrent::Promise.new{10}.then{|x| x * 2}.then{|result| result - 10 }
```

And so on, and so on, and so on...

```ruby
p = Concurrent::Promise.fulfill(20).
    then{|result| result - 10 }.
    then{|result| result * 3 }.
    then{|result| result % 5 }
```

Newly created promise state depends on the parent's one:
- if parent is *unscheduled* the child will be *unscheduled*
- if parent is *pending* the child will be *pending*
- if parent is *fulfilled* the child will be *pending*
- if parent is *rejected* the child will be *pending*
Promises are executed asynchronously so a newly-created promise could be in a different state right after
`then` returns, for example a child of a *rejected* parent could be already *fulfilled* or *rejected*

```ruby
p = Concurrent::Promise.execute{ "Hello, world!" }
p.state   #=> :pending
p.pending? #=> true
```

Wait a little bit, and the promise will resolve and provide a value

```ruby
p = Concurrent::Promise.execute{ "Hello, world!" }
sleep(0.1)

p.state      #=> :fulfilled
p.fulfilled? #=> true
p.value      #=> "Hello, world!"
```

If an exception occurs, the promise will be rejected and will provide
a reason for the rejection

```ruby
p = Concurrent::Promise.execute{ raise StandardError.new("Here comes the Boom!") }
sleep(0.1)

p.state     #=> :rejected
p.rejected? #=> true
p.reason    #=> "#<StandardError: Here comes the Boom!>"
```

### Rejection

When a promise is rejected all its children will be receive the reason as the rejection callable parameter.

```ruby
p = [ Concurrent::Promise.execute{ Thread.pass; raise StandardError } ]

c1 = p.then(Proc.new{ |reason| 42 })
c2 = p.then(Proc.new{ |reason| raise 'Boom!' })


sleep(0.1)

c1.state #=> :fulfilled
c2.state  #=> :rejected
```

Once a promise is rejected it will continue to accept children that will receive immediately
rejection (they will be executed asynchronously)

### Aliases

`then` method is the most generic one: it accepts a block to be executed upon parent fulfillment
and a callable to be executed upon parent rejection. At least one of them should be passed.
Default block is `{ |result| result }` that fulfills the child with the parent value.
Default callable is `{ |reason| raise reason }` that rejects the child with the parent reason.

`on_success { |result| ... }` is the same as `then {|result| ... }`
`rescue { |reason| ... }` is the same as `then(Proc.new { |reason| ... } )`
`rescue` is aliased by `catch` and `on_error`

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

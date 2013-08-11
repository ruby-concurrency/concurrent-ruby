# Promises, Promises...

A promise is the most powerful and versatile of the concurrency objects in this library.
Promises are inspired by the JavaScript [Promises/A](http://wiki.commonjs.org/wiki/Promises/A)
and [Promises/A+](http://promises-aplus.github.io/promises-spec/) specifications.

> A promise represents the eventual value returned from the single completion of an operation.

Promises are similar to futures and share many of the same behaviours. Promises are far more robust,
however. Promises can be chained in a tree structure where each promise may have zero or more children.
Promises are chained using the `then` method. The result of a call to `then` is always another promise.
Promises are resolved asynchronously in the order they are added to the tree. Parents are guaranteed
to be resolved before their children. The result of each promise is passed to each of its children
upon resolution. When a promise is rejected all its children will be summarily rejected.

Promises have three possible states: *pending*, *rejected*, and *fulfilled*. When a promise is created it is set
to *pending* and will remain in that state until processing is complete. A completed promise is either *rejected*,
indicating that an exception was thrown during processing, or *fulfilled*, indicating succedd. If a promise is
*fulfilled* its `value` will be updated to reflect the result of the operation. If *rejected* the `reason` will
be updated with a reference to the thrown exception. The predicate methods `pending?`, `rejected`, and `fulfilled?`
can be called at any time to obtain the state of the promise, as can the `state` method, which returns a symbol.

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
p = Promise.new("Jerry", "D'Antonio") do |first, last|
      "#{last}, #{first}"
    end

# -or-

p = promise(10){|x| x * x * x }
```

Promises can be chained using the `then` method. The `then` method
accepts a block but no arguments. The result of the each promise is
passed as the block argument to chained promises

```ruby
p = promise(10){|x| x * 2}.then{|result| result - 10 }
```

And so on, and so on, and so on...

```ruby
p = promise(10){|x| x * 2}.
    then{|result| result - 10 }.
    then{|result| result * 3 }.
    then{|result| result % 5 }
```

Promises are executed asynchronously so a newly-created promise *should* always be in the pending state


```ruby
p = promise{ "Hello, world!" }
p.state   #=> :pending
p.pending? #=> true
```

Wait a little bit, and the promise will resolve and provide a value

```ruby
p = promise{ "Hello, world!" }
sleep(0.1)

p.state      #=> :fulfilled
p.fulfilled? #=> true

p.value      #=> "Hello, world!"

```

If an exception occurs, the promise will be rejected and will provide
a reason for the rejection

```ruby
p = promise{ raise StandardError.new("Here comes the Boom!") }
sleep(0.1)

p.state     #=> :rejected
p.rejected? #=> true

p.reason=>  #=> "#<StandardError: Here comes the Boom!>"
```

### Rejection

Much like the economy, rejection exhibits a trickle-down effect. When
a promise is rejected all its children will be rejected

```ruby
p = [ promise{ Thread.pass; raise StandardError } ]

10.times{|i| p << p.first.then{ i } }
sleep(0.1)

p.length      #=> 11
p.first.state #=> :rejected
p.last.state  #=> :rejected
```

Once a promise is rejected it will not accept any children. Calls
to `then` will continually return `self`

```ruby
p = promise{ raise StandardError }
sleep(0.1)

p.object_id        #=> 32960556
p.then{}.object_id #=> 32960556
p.then{}.object_id #=> 32960556
```

### Error Handling

Promises support error handling callbacks is a style mimicing Ruby's
own exception handling mechanism, namely `rescue`


```ruby
promise{ "dangerous operation..." }.rescue{|ex| puts "Bam!" }

# -or- (for the Java/C# crowd)
promise{ "dangerous operation..." }.catch{|ex| puts "Boom!" }

# -or- (for the hipsters)
promise{ "dangerous operation..." }.on_error{|ex| puts "Pow!" }
```

As with Ruby's `rescue` mechanism, a promise's `rescue` method can
accept an optional Exception class argument (defaults to `Exception`
when not specified)


```ruby
promise{ "dangerous operation..." }.rescue(ArgumentError){|ex| puts "Bam!" }
```

Calls to `rescue` can also be chained

```ruby
promise{ "dangerous operation..." }.
  rescue(ArgumentError){|ex| puts "Bam!" }.
  rescue(NoMethodError){|ex| puts "Boom!" }.
  rescue(StandardError){|ex| puts "Pow!" }
```

When there are multiple `rescue` handlers the first one to match the thrown
exception will be triggered

```ruby
promise{ raise NoMethodError }.
  rescue(ArgumentError){|ex| puts "Bam!" }.
  rescue(NoMethodError){|ex| puts "Boom!" }.
  rescue(StandardError){|ex| puts "Pow!" }

sleep(0.1)

#=> Boom!
```

Trickle-down rejection also applies to rescue handlers. When a promise is rejected,
for any reason, its rescue handlers will be triggered. Rejection of the parent counts.

```ruby
promise{ Thread.pass; raise StandardError }.
  then{ true }.rescue{ puts 'Boom!' }.
  then{ true }.rescue{ puts 'Boom!' }.
  then{ true }.rescue{ puts 'Boom!' }.
  then{ true }.rescue{ puts 'Boom!' }.
  then{ true }.rescue{ puts 'Boom!' }
sleep(0.1)

#=> Boom!
#=> Boom!
#=> Boom!
#=> Boom!
#=> Boom!
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

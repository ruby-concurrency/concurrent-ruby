# Secret Agent Man

`Agent`s are inspired by [Clojure's](http://clojure.org/) [agent](http://clojure.org/agents) function.
An `Agent` is a single atomic value that represents an identity. The current value
of the `Agent` can be requested at any time (`deref`). Each `Agent` has a work queue and operates on
the global thread pool (see below). Consumers can `post` code blocks to the
`Agent`. The code block (function) will receive the current value of the `Agent` as its sole
parameter. The return value of the block will become the new value of the `Agent`. `Agent`s support
two error handling modes: fail and continue. A good example of an `Agent` is a shared incrementing
counter, such as the score in a video game.

An `Agent` must be initialize with an initial value. This value is always accessible via the `value`
(or `deref`) methods. Code blocks sent to the `Agent` will be processed in the order received. As
each block is processed the current value is updated with the result from the block. This update
is an atomic operation so a `deref` will never block and will always return the current value.

When an `Agent` is created it may be given an optional `validate` block and zero or more `rescue`
blocks. When a new value is calculated the value will be checked against the validator, if present.
If the validator returns `true` the new value will be accepted. If it returns `false` it will be
rejected. If a block raises an exception during execution the list of `rescue` blocks will be
seacrhed in order until one matching the current exception is found. That `rescue` block will
then be called an passed the exception object. If no matching `rescue` block is found, or none
were configured, then the exception will be suppressed.

`Agent`s also implement Ruby's [Observable](http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html).
Code that observes an `Agent` will receive a callback with the new value any time the value
is changed.

## Copy Options

Object references in Ruby are mutable. This can lead to serious problems when
the value of an `Agent` is a mutable reference. Which is always the case unless
the value is a `Fixnum`, `Symbol`, or similar "primative" data type. Each
`Agent` instance can be configured with a few options that can help protect the
program from potentially dangerous operations. Each of these options can be
optionally set when the `Agent` is created:

* `:dup_on_deref` when true the `Agent` will call the `#dup` method on the
  `value` object every time the `#value` methid is called (default: false)
* `:freeze_on_deref` when true the `Agent` will call the `#freeze` method on the
  `value` object every time the `#value` method is called (default: false)
* `:copy_on_deref` when given a `Proc` object the `Proc` will be run every time
  the `#value` method is called. The `Proc` will be given the current `value` as
  its only parameter and the result returned by the block will be the return
  value of the `#value` call. When `nil` this option will be ignored (default:
  nil)

## Examples

A simple example:

```ruby
require 'concurrent'

score = Concurrent::Agent.new(10)
score.value #=> 10

score << proc{|current| current + 100 }
sleep(0.1)
score.value #=> 110

score << proc{|current| current * 2 }
sleep(0.1)
score.value #=> 220

score << proc{|current| current - 50 }
sleep(0.1)
score.value #=> 170
```

With validation and error handling:

```ruby
score = Concurrent::Agent.new(0).validate{|value| value <= 1024 }.
          rescue(NoMethodError){|ex| puts "Bam!" }.
          rescue(ArgumentError){|ex| puts "Pow!" }.
          rescue{|ex| puts "Boom!" }
score.value #=> 0

score << proc{|current| current + 2048 }
sleep(0.1)
score.value #=> 0

score << proc{|current| raise ArgumentError }
sleep(0.1)
#=> puts "Pow!"
score.value #=> 0

score << proc{|current| current + 100 }
sleep(0.1)
score.value #=> 100
```

With observation:

```ruby
bingo = Class.new{
  def update(time, score)
    puts "Bingo! [score: #{score}, time: #{time}]" if score >= 100
  end
}.new

score = Concurrent::Agent.new(0)
score.add_observer(bingo)

score << proc{|current| sleep(0.1); current += 30 }
score << proc{|current| sleep(0.1); current += 30 }
score << proc{|current| sleep(0.1); current += 30 }
score << proc{|current| sleep(0.1); current += 30 }

sleep(1)
#=> Bingo! [score: 120, time: 2013-07-22 21:26:08 -0400]
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

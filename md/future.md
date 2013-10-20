# We're Sending You Back to the Future!

`Future`s are inspired by [Clojure's](http://clojure.org/) [future](http://clojuredocs.org/clojure_core/clojure.core/future)
function. A future represents a promise to complete an action at some time in the future.
The action is atomic and permanent. The idea behind a future is to send an operation for
asynchronous completion, do other stuff, then return and retrieve the result of the async
operation at a later time. `Future`s run on the global thread pool (see below).

`Future`s have three possible states: *pending*, *rejected*, and *fulfilled*. When a `Future` is created it is set
to *pending* and will remain in that state until processing is complete. A completed `Future` is either *rejected*,
indicating that an exception was thrown during processing, or *fulfilled*, indicating succedd. If a `Future` is
*fulfilled* its `value` will be updated to reflect the result of the operation. If *rejected* the `reason` will
be updated with a reference to the thrown exception. The predicate methods `pending?`, `rejected`, and `fulfilled?`
can be called at any time to obtain the state of the `Future`, as can the `state` method, which returns a symbol.

Retrieving the value of a `Future` is done through the `value` (alias: `deref`) method. Obtaining the value of
a `Future` is a potentially blocking operation. When a `Future` is *rejected* a call to `value` will return `nil`
immediately. When a `Future` is *fulfilled* a call to `value` will immediately return the current value.
When a `Future` is *pending* a call to `value` will block until the `Future` is either *rejected* or *fulfilled*.
A *timeout* value can be passed to `value` to limit how long the call will block. If `nil` the call will
block indefinitely. If `0` the call will not block. Any other integer or float value will indicate the
maximum number of seconds to block.

The `Future` class also includes the Ruby standard library
[Observable](http://ruby-doc.org/stdlib-1.9.3/libdoc/observer/rdoc/Observable.html) module. On fulfillment
or rejection all observers will be notified according to the normal `Observable` behavior. The observer
callback function will be called with three parameters: the `Time` of fulfillment/rejection, the
final `value`, and the final `reason`. Observers added after fulfillment/rejection will still be
notified as normal. The notification will occur on the global thread pool.

## Examples

A fulfilled example:

```ruby
require 'concurrent'

count = Concurrent::Future{ sleep(10); 10 }
count.state #=> :pending
count.pending? #=> true

# do stuff...

count.value(0) #=> nil (does not block)

count.value #=> 10 (after blocking)
count.state #=> :fulfilled
count.fulfilled? #=> true
count.value #=> 10
```

A rejected example:

```ruby
count = Concurrent::Future.new{ sleep(10); raise StandardError.new("Boom!") }
count.state #=> :pending
count.pending? #=> true

deref(count) #=> nil (after blocking)
count.rejected? #=> true
count.reason #=> #<StandardError: Boom!> 
```

An example with observation:

```ruby
class Ticker
  Stock = Struct.new(:symbol, :name, :exchange)

  def update(time, value, reason)
    ticker = value.collect do |symbol|
      Stock.new(symbol['symbol'], symbol['name'], symbol['exch'])
    end

    output = ticker.join("\n")
    print "#{output}\n"
  end
end

yahoo = Finance.new('YAHOO')
future = Concurrent::Future.new { yahoo.update.suggested_symbols }
future.add_observer(Ticker.new)

# do important stuff...

#>> #<struct Ticker::Stock symbol="YHOO", name="Yahoo! Inc.", exchange="NMS">
#>> #<struct Ticker::Stock symbol="YHO.DE", name="Yahoo! Inc.", exchange="GER">
#>> #<struct Ticker::Stock symbol="YAHOY", name="Yahoo Japan Corporation", exchange="PNK">
#>> #<struct Ticker::Stock symbol="YAHOF", name="YAHOO JAPAN CORP", exchange="PNK">
#>> #<struct Ticker::Stock symbol="YOJ.SG", name="YAHOO JAPAN", exchange="STU">
#>> #<struct Ticker::Stock symbol="YHO.SG", name="YAHOO", exchange="STU">
#>> #<struct Ticker::Stock symbol="YHOO.BA", name="Yahoo! Inc.", exchange="BUE">
#>> #<struct Ticker::Stock symbol="YHO.DU", name="YAHOO", exchange="DUS">
#>> #<struct Ticker::Stock symbol="YHO.HM", name="YAHOO", exchange="HAM">
#>> #<struct Ticker::Stock symbol="YHO.BE", name="YAHOO", exchange="BER">
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

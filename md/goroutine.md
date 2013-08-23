# Go, Go, Gadget Goroutine!

A goroutine is the simplest of the concurrency utilities in this library. It is inspired by
[Go's](http://golang.org/) [goroutines](https://gobyexample.com/goroutines) and
[Erlang's](http://www.erlang.org/) [spawn](http://erlangexamples.com/tag/spawn/) keyword. The
`go` function is nothing more than a simple way to send a block to the global thread pool (see below)
for processing.

## Examples

```ruby
require 'concurrent'

go('foo'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Boom!\n" }
go('bar'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Pow!\n" }
go('baz'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Zap!\n" }
sleep(0.5)

>> foo
>> bar
>> baz
>> Boom!
>> Pow!
>> Zap!
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

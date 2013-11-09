# Dereferenceable

Object references in Ruby are mutable. This can lead to serious problems when
the `#value` of a concurrent object is a mutable reference. Which is always the
case unless the value is a `Fixnum`, `Symbol`, or similar "primitive" data type.
Most classes in this library that expose a `#value` getter method do so using
the `Dereferenceable` mixin module.

Objects with this mixin can be configured with a few options that can help protect
the program from potentially dangerous operations.

* `:dup_on_deref` when true  will call the `#dup` method on the
  `value` object every time the `#value` method is called (default: false)
* `:freeze_on_deref` when true  will call the `#freeze` method on the
  `value` object every time the `#value` method is called (default: false)
* `:copy_on_deref` when given a `Proc` object the `Proc` will be run every time
  the `#value` method is called. The `Proc` will be given the current `value` as
  its only parameter and the result returned by the block will be the return
  value of the `#value` call. When `nil` this option will be ignored (default:
  nil)

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

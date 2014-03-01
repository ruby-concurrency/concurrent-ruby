# Channel

`Channel` is a functional programming variation of `Actor`, based very loosely on the
[MailboxProcessor](http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx)
agent in [F#](http://msdn.microsoft.com/en-us/library/ee370357.aspx).
The `Actor` is used to create objects that receive messages from other
threads then processes those messages based on the behavior of the class. `Channel`
creates objects that receive messages and processe them using the block given
at construction. `Channel` is implemented as a subclass of
[Actor](https://github.com/jdantonio/concurrent-ruby/blob/master/md/actor.md)
and supports all message-passing methods of that class. `Channel` also supports pools 
with a shared mailbox.

See the [Actor](https://github.com/jdantonio/concurrent-ruby/blob/master/md/actor.md)
documentation for more detail.

## Usage

```ruby
require 'concurrent'

channel = Concurrent::Channel.new do |msg|
  sleep(1)
  puts "#{msg}\n"
end

channel.run! => #<Thread:0x007fa123d95fc8 sleep>

channel.post("Hello, World!") => 1
# wait...
=> Hello, World!

future = channel.post? "Don't Panic." => #<Concurrent::Contract:0x007fa123d6d9d8 @state=:pending...
future.pending? => true
# wait...
=> "Don't Panic."
future.fulfilled? => true

channel.stop => true
```

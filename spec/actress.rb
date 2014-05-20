# require 'spec_helper'
require 'concurrent/actress'

# describe Concurrent::Actress do
# FIXME it does not work in Rspec environment

class Ping
  include Concurrent::Actress::Context

  def initialize(queue)
    @queue = queue
  end

  def on_message(message)
    case message
    when :terminate
      terminate!
    when :child
      Concurrent::Actress::AdHoc.spawn(:pong) { -> m { @queue << m } }
    else
      @queue << message
      message
    end
  end
end

# def trace!
#   set_trace_func proc { |event, file, line, id, binding, classname|
#     # thread = eval('Thread.current', binding).object_id.to_s(16)
#     printf "%8s %20s %20s %s %s:%-2d\n", event, id, classname, nil, file, line
#   }
#   yield
# ensure
#   set_trace_func nil
# end

def assert condition
  unless condition
    require 'pry'
    binding.pry
    raise
  end
end


Array.new(100).map do
  Thread.new do
    20.times do |i|
      # it format('--- %3d ---', i) do
      puts format('--- %3d ---', i)
      # trace! do
      queue = Queue.new
      actor = Ping.spawn :ping, queue

      # when spawn returns children are set
      assert Concurrent::Actress::ROOT.send(:core).instance_variable_get(:@children).include?(actor)

      actor << 'a' << 1
      assert queue.pop == 'a'
      assert actor.ask(2).value == 2

      assert actor.parent == Concurrent::Actress::ROOT
      assert Concurrent::Actress::ROOT.path == '/'
      assert actor.path == '/ping'
      child = actor.ask(:child).value
      assert child.path == '/ping/pong'
      queue.clear
      child.ask(3)
      assert queue.pop == 3

      actor << :terminate
      assert actor.ask(:blow_up).wait.rejected?
    end
  end
end.each(&:join)

# end
# end

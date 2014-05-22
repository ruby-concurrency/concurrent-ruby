require 'spec_helper'
require 'concurrent/actress'

EXECUTOR = Concurrent::ThreadPoolExecutor.new(
    min_threads:     [2, Concurrent.processor_count].max,
    max_threads:     [20, Concurrent.processor_count * 15].max,
    idletime:        2 * 60, # 2 minutes
    max_queue:       0, # unlimited
    overflow_policy: :abort # raise an exception
)

describe Concurrent::Actress do

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
        Concurrent::Actress::AdHoc.spawn(name: :pong, executor: EXECUTOR) { -> m { @queue << m } }
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
      # require 'pry'
      # binding.pry
      raise
      puts "--- \n#{caller.join("\n")}"
    end
  end


  # FIXME increasing this does not work in Rspec environment
  1.times do |i|
    it format('run %3d', i) do
      # puts format('run %3d', i)
      Array.new(10).map do
        Thread.new do
          10.times do
            # trace! do
            queue = Queue.new
            actor = Ping.spawn name: :ping, executor: EXECUTOR, args: [queue]

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
    end
  end
end

require 'thread'
require 'concurrent/options_parser'
require 'concurrent/collection/priority_queue'

module Concurrent

  class TimerSet

    def initialize(opts = {})
      @mutex = Mutex.new
      @queue = PriorityQueue.new(order: :min)
      @executor = OptionsParser::get_executor_from(opts)
      @thread = nil
    end

    def post(intended_time, &block)
      raise ArgumentError.new('no block given') unless block_given?
      time = calculate_schedule_time(intended_time)
      @mutex.synchronize{ @queue.push(Task.new(time, block)) }
      check_processing_thread
    end

    private

    Task = Struct.new(:time, :op) do
      include Comparable
      def <=>(other)
        self.time <=> other.time
      end
    end

    def calculate_schedule_time(intended_time, now = Time.now)
      if intended_time.is_a?(Time)
        raise SchedulingError.new('schedule time must be in the future') if intended_time <= now
        intended_time.to_f
      else
        raise SchedulingError.new('seconds must be greater than zero') if intended_time.to_f <= 0.0
        now.to_f + intended_time.to_f
      end
    end

    def check_processing_thread
      if @thread && @thread.status == 'sleep'
        @thread.wakeup
      elsif @thread.nil? || ! @thread.alive?
        @thread = Thread.new do
          Thread.current.abort_on_exception = false
          process_tasks
        end
      end
    end

    def next_task
      @mutex.synchronize do
        unless @queue.empty? || @queue.peek.time > Time.now.to_f
          @queue.pop
        else
          nil
        end
      end
    end

    def next_sleep_interval
      @mutex.synchronize do
        if @queue.empty?
          nil
        else
          @queue.peek.time - Time.now.to_f
        end
      end
    end

    def process_tasks
      loop do
        while task = next_task do
          @executor.post(&task.op)
        end
        if (interval = next_sleep_interval).nil?
          break
        else
          sleep([interval, 60].min)
        end
      end
    end
  end
end

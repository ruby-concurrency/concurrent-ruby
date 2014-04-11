require 'concurrent/ivar'
require 'concurrent/utilities/timer'
require 'concurrent/executor/safe_task_executor'

module Concurrent

  class ScheduledTask < IVar

    SchedulingError = Class.new(ArgumentError)

    attr_reader :schedule_time

    def initialize(schedule_time, opts = {}, &block)
      raise SchedulingError.new('no block given') unless block_given?
      calculate_schedule_time!(schedule_time) # raise exception if in past

      super(NO_VALUE, opts)

      @state = :unscheduled
      @intended_schedule_time = schedule_time
      @schedule_time = nil
      @task = block
    end

    # @since 0.5.0
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @schedule_time = calculate_schedule_time!(@intended_schedule_time).freeze
        do_next_interval
        self
      end
    end

    # @since 0.5.0
    def self.execute(schedule_time, opts = {}, &block)
      return ScheduledTask.new(schedule_time, opts, &block).execute
    end

    def cancelled?
      state == :cancelled
    end

    def in_progress?
      state == :in_progress
    end

    def cancel
      if_state(:unscheduled, :pending) do
        @state = :cancelled
        event.set
        true
      end
    end
    alias_method :stop, :cancel

    def add_observer(*args)
      if_state(:unscheduled, :pending, :in_progress) do
        observers.add_observer(*args)
      end
    end

    protected :set, :fail, :complete

    private

    def do_work
      if compare_and_set_state(:in_progress, :pending)
        success, val, reason = SafeTaskExecutor.new(@task).execute

        mutex.synchronize do
          set_state(success, val, reason)
          event.set
        end

        time = Time.now
        observers.notify_and_delete_observers{ [time, self.value, reason] }
      end
    end

    def do_next_interval
      return if cancelled?

      interval = mutex.synchronize do
        [60, [(@schedule_time.to_f - Time.now.to_f), 0].max].min
      end

      if interval > 0
        Concurrent::timer(interval, &method(:do_next_interval))
      else
        do_work
      end
    end

    def calculate_schedule_time!(schedule_time, now = Time.now)
      if schedule_time.is_a?(Time)
        raise SchedulingError.new('schedule time must be in the future') if schedule_time <= now
        schedule_time.dup
      else
        raise SchedulingError.new('seconds must be greater than zero') if schedule_time.to_f <= 0.0
        now + schedule_time.to_f
      end
    end
  end
end

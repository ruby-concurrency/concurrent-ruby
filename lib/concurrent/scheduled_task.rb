require 'observer'
require 'concurrent/obligation'
require 'concurrent/safe_task_executor'

module Concurrent

  class ScheduledTask
    include Obligation

    attr_reader :schedule_time

    def initialize(schedule_time, opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_obligation
      @observers = CopyOnWriteObserverSet.new
      @state = :unscheduled
      @schedule_time = adjust_schedule_time(schedule_time, Time.now).freeze
      @task = block
      set_deref_options(opts)
    end

    def execute
      if compare_and_set_state(:pending, :unscheduled)
        Thread.new { work }
        self
      end
    end

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
      mutex.synchronize do
        return false unless [:unscheduled, :pending].include? @state

        @state = :cancelled
        event.set
        true
      end
    end

    alias_method :stop, :cancel

    def add_observer(observer, func = :update)
      mutex.synchronize do
        return false unless [:unscheduled, :pending, :in_progress].include?(@state)
        @observers.add_observer(observer, func)
      end
    end

    protected

    def work
      sleep_until_scheduled_time

      if compare_and_set_state(:in_progress, :pending)
        success, val, reason = SafeTaskExecutor.new(@task).execute

        mutex.synchronize do
          set_state(success, val, reason)
          event.set
        end

        @observers.notify_and_delete_observers(Time.now, self.value, reason)
      end

    end

    private

    def sleep_until_scheduled_time
      while (diff = @schedule_time.to_f - Time.now.to_f) > 0
        sleep(diff > 60 ? 60 : diff)
      end
    end

    def adjust_schedule_time(schedule_time, now)
      if schedule_time.is_a?(Time)
        raise ArgumentError.new('schedule time must be in the future') if schedule_time <= now
        schedule_time.dup
      else
        raise ArgumentError.new('seconds must be greater than zero') if schedule_time.to_f <= 0.0
        now + schedule_time.to_f
      end
    end

    def compare_and_set_state(next_state, expected_current)
      mutex.synchronize do
        if @state == expected_current
          @state = next_state
          true
        else
          false
        end
      end
    end

  end
end

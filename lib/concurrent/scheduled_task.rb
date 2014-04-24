require 'concurrent/ivar'
require 'concurrent/utility/timer'
require 'concurrent/executor/safe_task_executor'

module Concurrent

  class ScheduledTask < IVar

    attr_reader :schedule_time

    def initialize(intended_time, opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      TimerSet.calculate_schedule_time(intended_time) # raises exceptons

      super(NO_VALUE, opts)

      self.observers = CopyOnNotifyObserverSet.new
      @intended_time =  intended_time
      @state = :unscheduled
      @task = block
    end

    # @since 0.5.0
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @schedule_time = TimerSet.calculate_schedule_time(@intended_time)
        Concurrent::timer(@schedule_time.to_f - Time.now.to_f, &method(:process_task))
        self
      end
    end

    # @since 0.5.0
    def self.execute(intended_time, opts = {}, &block)
      return ScheduledTask.new(intended_time, opts, &block).execute
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

    def add_observer(*args, &block)
      if_state(:unscheduled, :pending, :in_progress) do
        observers.add_observer(*args, &block)
      end
    end

    protected :set, :fail, :complete

    private

    def process_task
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
  end
end

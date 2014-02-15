require 'observer'
require 'concurrent/obligation'
require 'concurrent/safe_task_executor'

module Concurrent

  class ScheduledTask
    include Obligation
    include Observable

    attr_reader :schedule_time

    def initialize(schedule_time, opts = {}, &block)
      now = Time.now

      if ! block_given?
        raise ArgumentError.new('no block given')
      elsif schedule_time.is_a?(Time)
        if schedule_time <= now
          raise ArgumentError.new('schedule time must be in the future')
        else
          @schedule_time = schedule_time.dup
        end
      elsif schedule_time.to_f <= 0.0
        raise ArgumentError.new('seconds must be greater than zero')
      else
        @schedule_time = now + schedule_time.to_f
      end

      init_obligation
      @state = :unscheduled
      @schedule_time.freeze
      @task = block
      set_deref_options(opts)
    end

    def execute
      mutex.synchronize do
        return unless @state == :unscheduled
        @state = :pending
      end

      @thread = Thread.new do
        Thread.current.abort_on_exception = false
        work
      end
      return self
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
      return false if mutex.locked?
      return mutex.synchronize do
        if @state == :pending
          @state = :cancelled
          event.set
          true
        else
          false
        end
      end
    end
    alias_method :stop, :cancel

    def add_observer(observer, func = :update)
      return false unless [:pending, :in_progress].include?(state)
      super
    end

    protected

    def work
      while (diff = @schedule_time.to_f - Time.now.to_f) > 0
        sleep( diff > 60 ? 60 : diff )
      end

      to_execute = false

      mutex.synchronize do
        if @state == :pending
          @state = :in_progress
          to_execute = true
        end
      end

      if to_execute
        success, val, reason = SafeTaskExecutor.new(@task).execute

        mutex.synchronize do
          set_state(success, val, reason)
          changed
        end
      end

      if self.changed?
        notify_observers(Time.now, self.value, reason)
        delete_observers
      end
      event.set
      self.stop
    end

  end
end

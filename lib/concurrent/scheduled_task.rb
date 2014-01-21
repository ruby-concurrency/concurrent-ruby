require 'observer'
require 'concurrent/obligation'

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

      @state = :pending
      @schedule_time.freeze
      @task = block
      init_mutex
      set_deref_options(opts)

      @thread = Thread.new{ work }
      @thread.abort_on_exception = false
    end

    def cancelled?
      return @state == :cancelled
    end

    def in_progress?
      return @state == :in_progress
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
      return false unless [:pending, :in_progress].include?(@state)
      super
    end

    protected

    def work
      while (diff = @schedule_time.to_f - Time.now.to_f) > 0
        sleep( diff > 60 ? 60 : diff )
      end
      
      if @state == :pending
        mutex.synchronize do
          @state = :in_progress
          begin
            @value = @task.call
            @state = :fulfilled
          rescue => ex
            @reason = ex
            @state = :rejected
          ensure
            changed
          end
        end
      end

      if self.changed?
        notify_observers(Time.now, self.value, @reason)
        delete_observers
      end
      event.set
      self.stop
    end
  end
end

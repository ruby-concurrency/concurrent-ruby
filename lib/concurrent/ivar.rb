require 'thread'

require 'concurrent/obligation'
require 'concurrent/copy_on_write_observer_set'

module Concurrent

  MultipleAssignmentError = Class.new(StandardError)

  class IVar
    include Obligation

    NO_VALUE = Object.new

    # Create a new +Ivar+ in the +:pending+ state with the (optional) initial value.
    #
    # @param [Object] value the initial value
    # @param [Hash] opts the options to create a message with
    # @option opts [String] :dup_on_deref (false) call +#dup+ before returning the data
    # @option opts [String] :freeze_on_deref (false) call +#freeze+ before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given +Proc+ passing the internal value and
    #   returning the value returned from the proc
    def initialize(value = NO_VALUE, opts = {})
      init_obligation
      @observers = CopyOnWriteObserverSet.new
      set_deref_options(opts)

      if value == NO_VALUE
        @state = :pending
      else
        set(value)
      end
    end

    # Add an observer on this object that will receive notification on update.
    #
    # Upon completion the +IVar+ will notify all observers in a thread-say way. The +func+
    # method of the observer will be called with three arguments: the +Time+ at which the
    # +Future+ completed the asynchronous operation, the final +value+ (or +nil+ on rejection),
    # and the final +reason+ (or +nil+ on fulfillment).
    #
    # @param [Object] observer the object that will be notified of changes
    # @param [Symbol] func symbol naming the method to call when this +Observable+ has changes`
    def add_observer(observer, func = :update)
      direct_notification = false

      mutex.synchronize do
        if event.set?
          direct_notification = true
        else
          @observers.add_observer(observer, func)
        end
      end

      observer.send(func, Time.now, self.value, reason) if direct_notification
      func
    end

    def set(value)
      complete(true, value, nil)
    end

    def fail(reason = nil)
      complete(false, nil, reason)
    end

    def complete(success, value, reason)
      mutex.synchronize do
        raise MultipleAssignmentError.new('multiple assignment') if [:fulfilled, :rejected].include? @state
        set_state(success, value, reason)
        event.set
      end

      @observers.notify_and_delete_observers(Time.now, self.value, self.reason)
    end

  end
end

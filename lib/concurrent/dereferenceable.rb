module Concurrent

  # Object references in Ruby are mutable. This can lead to serious problems when
  # the `#value` of a concurrent object is a mutable reference. Which is always the
  # case unless the value is a `Fixnum`, `Symbol`, or similar "primitive" data type.
  # Most classes in this library that expose a `#value` getter method do so using the
  # `Dereferenceable` mixin module. 
  # 
  # Objects with this mixin can be configured with a few options that can help protect
  # the program from potentially dangerous operations.
  # 
  # * `:dup_on_deref` when true  will call the `#dup` method on the `value` object every time the `#value` method is called (default: false)
  # * `:freeze_on_deref` when true  will call the `#freeze` method on the `value` object every time the `#value` method is called (default: false)
  # * `:copy_on_deref` when given a `Proc` object the `Proc` will be run every time the `#value` method is called. The `Proc` will be given the current `value` as its only parameter and the result returned by the block will be the return value of the `#value` call. When `nil` this option will be ignored (default: nil)
  module Dereferenceable

    # Return the value this object represents after applying the options specified
    # by the `#set_deref_options` method.
    #
    # When multiple deref options are set the order of operations is strictly defined.
    # The order of deref operations is:
    # * `:copy_on_deref`
    # * `:dup_on_deref`
    # * `:freeze_on_deref`
    #
    # Because of this ordering there is no need to `#freeze` an object created by a
    # provided `:copy_on_deref` block. Simply set `:freeze_on_deref` to `true`.
    # Setting both `:dup_on_deref` to `true` and `:freeze_on_deref` to `true` is
    # as close to the behavior of a "pure" functional language (like Erlang, Clojure,
    # or Haskell) as we are likely to get in Ruby.
    # 
    # This method is thread-safe and synchronized with the internal `#mutex`.
    #
    # @return [Object] the current value of the object
    def value
      mutex.lock
      apply_deref_options(@value)
    ensure
      mutex.unlock
    end

    alias_method :deref, :value

    protected

    # Set the internal value of this object
    #
    # @param [Object] val the new value
    def value=(val)
      mutex.lock
      @value = val
    ensure
      mutex.unlock
    end

    # A mutex lock used for synchronizing thread-safe operations. Methods defined
    # by `Dereferenceable` are synchronized using the `Mutex` returned from this
    # method. Operations performed by the including class that operate on the
    # `@value` instance variable should be locked with this `Mutex`.
    #
    # @return [Mutex] the synchronization object
    def mutex
      @mutex
    end

    # Initializes the internal `Mutex`. 
    #
    # @note This method *must* be called from within the constructor of the including class.
    #
    # @see #mutex
    def init_mutex
      @mutex = Mutex.new
    end

    # Set the options which define the operations #value performs before
    # returning data to the caller (dereferencing).
    #
    # @note Most classes that include this module will call `#set_deref_options`
    # from within the constructor, thus allowing these options to be set at
    # object creation.
    #
    # @param [Hash] opts the options defining dereference behavior.
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing the internal value and
    #   returning the value returned from the proc
    def set_deref_options(opts = {})
      mutex.lock
      @dup_on_deref = opts[:dup_on_deref] || opts[:dup]
      @freeze_on_deref = opts[:freeze_on_deref] || opts[:freeze]
      @copy_on_deref = opts[:copy_on_deref] || opts[:copy]
      @do_nothing_on_deref = !(@dup_on_deref || @freeze_on_deref || @copy_on_deref)
      nil
    ensure
      mutex.unlock
    end

    # @!visibility private
    def apply_deref_options(value) # :nodoc:
      return nil if value.nil?
      return value if @do_nothing_on_deref
      value = @copy_on_deref.call(value) if @copy_on_deref
      value = value.dup if @dup_on_deref
      value = value.freeze if @freeze_on_deref
      value
    end
  end
end

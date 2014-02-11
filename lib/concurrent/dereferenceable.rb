module Concurrent

  # Object references in Ruby are mutable. This can lead to serious problems when
  # the `#value` of a concurrent object is a mutable reference. Which is always the
  # case unless the value is a `Fixnum`, `Symbol`, or similar "primitive" data type.
  # Most classes in this library that expose a `#value` getter method do so using
  # this mixin module.
  module Dereferenceable

    # Set the options which define the operations #value performs before
    # returning data to the caller (dereferencing).
    #
    # @note Many classes that include this module will call #set_deref_options
    # from within the constructor, thus allowing these options to be set at
    # object creation.
    #
    # @param [Hash] opts the options defining dereference behavior.
    # @option opts [String] :dup_on_deref Call #dup before returning the data (default: false)
    # @option opts [String] :freeze_on_deref Call #freeze before returning the data (default: false)
    # @option opts [String] :copy_on_deref Call the given `Proc` passing the internal value and
    #   returning the value returned from the proc (default: `nil`)
    def set_deref_options(opts = {})
      mutex.synchronize do
        @dup_on_deref = opts[:dup_on_deref] || opts[:dup]
        @freeze_on_deref = opts[:freeze_on_deref] || opts[:freeze]
        @copy_on_deref = opts[:copy_on_deref] || opts[:copy]
        @do_nothing_on_deref = ! (@dup_on_deref || @freeze_on_deref || @copy_on_deref)
      end
    end

    # Return the value this object represents after applying the options specified
    # by the #set_deref_options method.
    def value
      mutex.synchronize do
        return nil if @value.nil?
        return @value if @do_nothing_on_deref
        value = @value
        value = @copy_on_deref.call(value) if @copy_on_deref
        value = value.dup if @dup_on_deref
        value = value.freeze if @freeze_on_deref
        value
      end
    end
    alias_method :deref, :value

    protected

    def mutex # :nodoc:
      @mutex
    end

    def init_mutex
      @mutex = Mutex.new
    end
  end
end

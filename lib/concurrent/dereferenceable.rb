module Concurrent

  module Dereferenceable

    def set_deref_options(opts = {})
      mutex.synchronize do
        @dup_on_deref = opts[:dup_on_deref] || opts[:dup] || false
        @freeze_on_deref = opts[:freeze_on_deref] || opts[:freeze] || false
        @copy_on_deref = opts[:copy_on_deref] || opts[:copy]
        @do_nothing_on_deref = ! (@dup_on_deref || @freeze_on_deref || @copy_on_deref)
      end
    end

    def value
      return nil if @value.nil?
      return @value if @do_nothing_on_deref
      return mutex.synchronize do
        value = @value
        value = @copy_on_deref.call(value) if @copy_on_deref
        value = value.dup if @dup_on_deref
        value = value.freeze if @freeze_on_deref
        value
      end
    end
    alias_method :deref, :value

    protected

    def mutex
      @mutex ||= Mutex.new
    end
  end
end

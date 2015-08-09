module Concurrent

  # Provides `volatile` (in the JVM's sense) attribute accessors implemented
  # atop of `Concurrent::AtomicReference`.
  #
  # Additionally, the including class will also receive a `initialize_copy(other)` method.
  # This method will copy all attribute values from `other` and set the corresponding values
  # in `self`. Both objects must be of the same class (or subclass).
  #
  # @see https://docs.oracle.com/javase/tutorial/essential/concurrency/atomic.html Java AtomicAccess
  module Volatile

    # @!macro [new] synchronization_object_method_self_attr_volatile
    #    
    #   Creates methods for reading and writing to a instance variable with volatile (Java semantic) instance variable.
    #
    #   Several methods will be defined for each volatile attribute:
    #   * `<attr_name>()`: attribute reader
    #   * `<attr_name>=(value)`: attribute writer
    #   * `compare_and_set_<attr_name>(old_value, new_value)`: write `new_value` if and only if the
    #     current value equals `old_value`
    #   * `cas_<attr_name>(old_value, new_value)`: alias for `compare_and_set_<attr_name>`
    #   * `lazy_set_<attr_name>(value)`: alias for `<attr_name>=`
    #
    #   @example
    #     class Foo
    #       extend Concurrent::Volatile
    #       attr_volatile :foo, :bar
    #
    #       def initialize(foo, bar = nil)
    #         super() # must super() into parent initializers before using the volatile attribute accessors
    #         self.foo = foo
    #         self.bar = bar
    #       end
    #     end
    #
    #     baz = Foo.new(10)
    #
    #     puts baz.foo                  #=> 10    | volatile read
    #     baz.foo = 1                   #=> 1     | volatile write
    #     baz.lazy_set_foo(2)           #=> 2     | volatile write
    #     baz.compare_and_set_foo(2, 3) #=> true  | strong CAS
    #     baz.cas_foo(1, 2)             #=> false | strong CAS
    #
    #   @param [Array<Symbol>] attr_names names of the accessors to be defined
    #   @return [Array<Symbol>] names of defined accessor methods

    # @!macro synchronization_object_method_self_attr_volatile
    def attr_volatile(*attr_names)
      return if attr_names.empty?
      include(Module.new do
        atomic_ref_setup = attr_names.map {|attr_name| "@__#{attr_name} = Concurrent::AtomicReference.new"}
        initialize_copy_setup = attr_names.zip(atomic_ref_setup).map do |attr_name, ref_setup|
          "#{ref_setup}(other.instance_variable_get(:@__#{attr_name}).get)"
        end
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def initialize(*)
            super
            #{atomic_ref_setup.join('; ')}
          end

          def initialize_copy(other)
            super
            #{initialize_copy_setup.join('; ')}
          end
        RUBY_EVAL

        attr_names.each do |attr_name|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{attr_name}
              @__#{attr_name}.get
            end

            def #{attr_name}=(value)
              @__#{attr_name}.set(value)
            end

            def compare_and_set_#{attr_name}(old_value, new_value)
              @__#{attr_name}.compare_and_set(old_value, new_value)
            end
          RUBY_EVAL

          alias_method :"cas_#{attr_name}", :"compare_and_set_#{attr_name}"
          alias_method :"lazy_set_#{attr_name}", :"#{attr_name}="
        end
      end)
    end
  end
end

module Concurrent
  module Synchronization
    # Similar to Struct but the fields are immutable and always visible (like Java final fields)
    # @example
    #   Person = ImmutableStruct.with_fields :name, :age
    #   Person.new 'John Doe', 15
    #   Person['John Doe', 15]
    #   Person['John Doe', 15].members # => [:name, :age]
    #   Person['John Doe', 15].values  # => ['John Doe', 15]
    class ImmutableStruct < Synchronization::Object
      def self.with_fields(*names, &block)
        Class.new(self) do
          attr_reader(*names)

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def initialize(#{names.join(', ')})
              #{names.map { |n| '@' + n.to_s }.join(', ')} = #{names.join(', ')}
              ensure_ivar_visibility!
            end

            def members
              #{names.inspect}
            end

            def self.members
              #{names.inspect}
            end
          RUBY

          instance_eval &block if block
        end
      end

      # Define equality based on class and members' equality. This is optional since for CAS operation
      # it may be required to compare references which is default behaviour of this class.
      def self.define_equality!
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def ==(other)
            self.class == other.class &&
              #{members.map { |name| "self.#{name} == other.#{name}" }.join(" && ")}
          end
        RUBY
      end

      def self.[](*args)
        new *args
      end

      include Enumerable

      def each(&block)
        return to_enum unless block_given?
        members.zip(values).each(&block)
      end

      def size
        members.size
      end

      def values
        members.map { |name| send name }
      end

      alias_method :to_a, :values
    end
  end
end

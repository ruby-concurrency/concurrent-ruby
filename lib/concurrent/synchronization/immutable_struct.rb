module Concurrent
  module Synchronization
    class ImmutableStruct < Synchronization::Object
      def self.with_fields(*names, &block)
        Class.new(self) do
          attr_reader(*names)
          instance_eval &block if block

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def initialize(#{names.join(', ')})
              #{names.map { |n| '@' + n.to_s }.join(', ')} = #{names.join(', ')}
              ensure_ivar_visibility!
            end
          RUBY
        end
      end

      def self.[](*args)
        new *args
      end
    end
  end
end

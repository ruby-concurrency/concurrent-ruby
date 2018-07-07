module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    module AbstractStruct

      # @!visibility private
      def initialize(*values, **kw_values)
        super()
        ns_initialize(*values, **kw_values)
      end

      # @!macro [attach] struct_keyword_init
      #
      #   Returns `true` if the struct uses keyword arguments.
      #
      #   @return [Boolean] true if struct uses keyword arguments
      def keyword_init?
        self.class::KEYWORD_INIT
      end

      # @!macro [attach] struct_length
      #
      #   Returns the number of struct members.
      #
      #   @return [Fixnum] the number of struct members
      def length
        self.class::MEMBERS.length
      end
      alias_method :size, :length

      # @!macro [attach] struct_members
      #
      #   Returns the struct members as an array of symbols.
      #
      #   @return [Array] the struct members as an array of symbols
      def members
        self.class::MEMBERS.dup
      end

      protected

      # @!macro struct_values
      #
      # @!visibility private
      def ns_values
        @values.dup
      end

      # @!macro struct_values_at
      #
      # @!visibility private
      def ns_values_at(indexes)
        @values.values_at(*indexes)
      end

      # @!macro struct_to_h
      #
      # @!visibility private
      def ns_to_h
        length.times.reduce({}){|memo, i| memo[self.class::MEMBERS[i]] = @values[i]; memo}
      end

      # @!macro struct_get
      #
      # @!visibility private
      def ns_get(member)
        if member.is_a? Integer
          if member >= @values.length
            raise IndexError.new("offset #{member} too large for struct(size:#{@values.length})")
          end
          @values[member]
        else
          send(member)
        end
      rescue NoMethodError
        raise NameError.new("no member '#{member}' in struct")
      end

      # @!macro struct_equality
      #
      # @!visibility private
      def ns_equality(other)
        self.class == other.class && self.values == other.values
      end

      # @!macro struct_each
      #
      # @!visibility private
      def ns_each
        values.each{|value| yield value }
      end

      # @!macro struct_each_pair
      #
      # @!visibility private
      def ns_each_pair
        @values.length.times do |index|
          yield self.class::MEMBERS[index], @values[index]
        end
      end

      # @!macro struct_select
      #
      # @!visibility private
      def ns_select
        values.select{|value| yield value }
      end

      # @!macro struct_inspect
      #
      # @!visibility private
      def ns_inspect
        struct = pr_underscore(self.class.ancestors[1])
        clazz = ((self.class.to_s =~ /^#<Class:/) == 0) ? '' : " #{self.class}"
        "#<#{struct}#{clazz} #{ns_to_h}>"
      end

      # @!macro struct_merge
      #
      # @!visibility private
      def ns_merge(other, &block)
        self.class.new(*self.to_h.merge(other, &block).values)
      end

      # @!visibility private
      def pr_underscore(clazz)
        word = clazz.to_s
        word.gsub!(/::/, '/')
        word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
        word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
        word.tr!("-", "_")
        word.downcase!
        word
      end

      # @!visibility private
      def self.define_struct_class(parent, base, name, members, kw_args, &block)
        clazz = Class.new(base || Object) do
          include parent
          self.const_set(:MEMBERS, members.collect{|member| member.to_s.to_sym}.freeze)
          self.const_set(:KEYWORD_INIT, !!kw_args[:keyword_init])
          def ns_initialize(*values, **kw_values)
            @values = if keyword_init?
              key_diff = kw_values.keys - members
              raise ArgumentError.new("unknown keywords: #{key_diff.join(',')}") unless key_diff.empty?
              members.map {|val| kw_values.fetch(val, nil)}
            else
              raise ArgumentError.new('struct size differs') if values.length > length
              values.fill(nil, values.length..length-1)
            end
          end
        end
        unless name.nil?
          begin
            parent.send :remove_const, name if parent.const_defined? name
            parent.const_set(name, clazz)
            clazz
          rescue NameError
            raise NameError.new("identifier #{name} needs to be constant")
          end
        end
        members.each_with_index do |member, index|
          clazz.send :remove_method, member if clazz.instance_methods.include? member
          clazz.send(:define_method, member) do
            @values[index]
          end
        end
        clazz.class_exec(&block) unless block.nil?
        clazz
      end
    end
  end
end

module YARD
  module Templates::Helpers
    # The helper module for HTML templates.
    module HtmlHelper
      def signature_types(meth, link = true)
        meth = convert_method_to_overload(meth)
        if meth.respond_to?(:object) && !meth.has_tag?(:return)
          meth = meth.object
        end

        type = options.default_return || ""
        if meth.tag(:return) && meth.tag(:return).types
          types = meth.tags(:return).map { |t| t.types ? t.types : [] }.flatten.uniq
          first = link ? h(types.first) : format_types([types.first], false)
          # if types.size == 2 && types.last == 'nil'
          #   type = first + '<sup>?</sup>'
          # elsif types.size == 2 && types.last =~ /^(Array)?<#{Regexp.quote types.first}>$/
          #   type = first + '<sup>+</sup>'
          # elsif types.size > 2
          #   type = [first, '...'].join(', ')
          if types == ['void'] && options.hide_void_return
            type = ""
          else
            type = link ? h(types.join(", ")) : format_types(types, false)
          end
        elsif !type.empty?
          type = link ? h(type) : format_types([type], false)
        end
        type = "(#{type}) " unless type.empty?
        type
      end
    end
  end
end

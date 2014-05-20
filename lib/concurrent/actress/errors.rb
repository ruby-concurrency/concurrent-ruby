module Concurrent
  module Actress
    Error = Class.new(StandardError)

    class ActressTerminated < Error
      include TypeCheck

      def initialize(reference)
        Type! reference, Reference
        super reference.path
      end
    end
  end
end

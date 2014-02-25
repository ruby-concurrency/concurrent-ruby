module Concurrent
  class Rescuer

    def initialize(clazz, &block)
      @clazz = clazz
      @block = block_given? ? block : Proc.new {}
    end

    def matches?(exception)
      @clazz === exception
    end

    def execute_if_matches(exception)
      @block.call if matches?(exception)
    end

  end
end
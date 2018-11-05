require_relative 'engine'

if Concurrent.ruby_version :<, 2, 0, 0
  # @!visibility private
  module Kernel
    def __dir__
      File.dirname __FILE__
    end
  end

  # @!visibility private
  class LoadError < ScriptError
    def path
      message.split(' -- ').last
    end
  end
end

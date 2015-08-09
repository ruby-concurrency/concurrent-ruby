require 'concurrent/utility/native_extension_loader' # load native part first

module Concurrent
  module Synchronization

    if Concurrent.on_jruby?

      # @!visibility private
      # @!macro internal_implementation_note
      class JavaObject < AbstractObject
      end
    end
  end
end

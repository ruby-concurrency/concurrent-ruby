
module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    ObjectImplementation = case
                     when Concurrent.on_cruby?
                       MriObject
                     when Concurrent.on_jruby?
                       JRubyObject
                     when Concurrent.on_rbx?
                       RbxObject
                     else
                       warn 'Possibly unsupported Ruby implementation'
                       MriObject
                     end
    private_constant :ObjectImplementation

    # TODO fix documentation
    # @!macro [attach] synchronization_object
    #
    #   Safe synchronization under any Ruby implementation.
    #   It provides methods like {#synchronize}, {#wait}, {#signal} and {#broadcast}.
    #   Provides a single layer which can improve its implementation over time without changes needed to
    #   the classes using it. Use {Synchronization::Object} not this abstract class.
    #
    #   @note this object does not support usage together with
    #     [`Thread#wakeup`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-wakeup)
    #     and [`Thread#raise`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-raise).
    #     `Thread#sleep` and `Thread#wakeup` will work as expected but mixing `Synchronization::Object#wait` and
    #     `Thread#wakeup` will not work on all platforms.
    #
    #   @see {Event} implementation as an example of this class use
    #
    #   @example simple
    #     class AnClass < Synchronization::Object
    #       def initialize
    #         super
    #         synchronize { @value = 'asd' }
    #       end
    #
    #       def value
    #         synchronize { @value }
    #       end
    #     end
    #
    class Object < ObjectImplementation

      # TODO split to be able to use just final fields
      # - object has mfence, volatile fields, and cas fields

      # TODO lock should be the public api, Object with private synchronize, signal, .. should be
      # private class just for concurrent-ruby, forbid inheritance of classes using it, like CountDownLatch
      # TODO in place CAS

      # @!method initialize
      #   @!macro synchronization_object_method_initialize

      # @!method ensure_ivar_visibility!
      #   @!macro synchronization_object_method_ensure_ivar_visibility

      # @!method self.attr_volatile(*names)
      #   @!macro synchronization_object_method_self_attr_volatile
    end
  end
end

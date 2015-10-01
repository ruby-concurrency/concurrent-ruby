module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    LockableObjectImplementation = case
                                   when Concurrent.on_cruby? && Concurrent.ruby_version(:<=, 1, 9, 3)
                                     MriMonitorLockableObject
                                   when Concurrent.on_cruby? && Concurrent.ruby_version(:>, 1, 9, 3)
                                     MriMutexLockableObject
                                   when defined? JRubyLockableObject
                                     JRubyLockableObject
                                   when Concurrent.on_rbx?
                                     RbxLockableObject
                                   else
                                     warn 'Possibly unsupported Ruby implementation'
                                     MriMonitorLockableObject
                                   end
    private_constant :LockableObjectImplementation

    # TODO (pitr 12-Sep-2015): make private for c-r, prohibit subclassing
    class LockableObject < LockableObjectImplementation

      # TODO (pitr 12-Sep-2015): we inherit too much ourselves :/
      def self.allow_only_direct_descendants!
        this = self
        singleton_class.send :define_method, :inherited do |child|
          # super child

          if child.superclass != this
            warn "all children of #{this} are final, subclassing is not supported use composition."
          end
        end
      end

      # @!method initialize(*args, &block)
      #   @!macro synchronization_object_method_initialize

      # @!method synchronize
      #   @!macro synchronization_object_method_synchronize

      # @!method initialize(*args, &block)
      #   @!macro synchronization_object_method_ns_initialize

      # @!method wait_until(timeout = nil, &condition)
      #   @!macro synchronization_object_method_ns_wait_until

      # @!method wait(timeout = nil)
      #   @!macro synchronization_object_method_ns_wait

      # @!method signal
      #   @!macro synchronization_object_method_ns_signal

      # @!method broadcast
      #   @!macro synchronization_object_method_ns_broadcast

    end
  end
end

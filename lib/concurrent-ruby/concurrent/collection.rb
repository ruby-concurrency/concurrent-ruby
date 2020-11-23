# frozen_string_literal: true

module Concurrent
  module Collection
    autoload :RubyNonConcurrentPriorityQueue, 'concurrent/collection/non_concurrent_priority_queue'
    autoload :CopyOnNotifyObserverSet, 'concurrent/collection/copy_on_notify_observer_set'
    autoload :CopyOnWriteObserverSet, 'concurrent/collection/copy_on_write_observer_set'
  end

  # TODO: Why is this scoped within Concurrent when logically it should be at
  # Concurrent::Collection?
  autoload :LockFreeStack, 'concurrent/collection/lock_free_stack'
end

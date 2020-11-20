# frozen_string_literal: true

module Concurrent
  autoload :AbstractExecutorService, 'concurrent/executor/abstract_executor_service'
  autoload :CachedThreadPool, 'concurrent/executor/cached_thread_pool'
  autoload :ExecutorService, 'concurrent/executor/executor_service'
  autoload :FixedThreadPool, 'concurrent/executor/fixed_thread_pool'
  autoload :ImmediateExecutor, 'concurrent/executor/immediate_executor'
  autoload :IndirectImmediateExecutor, 'concurrent/executor/indirect_immediate_executor'
  autoload :JavaExecutorService, 'concurrent/executor/java_executor_service'
  autoload :JavaSingleThreadExecutor, 'concurrent/executor/java_single_thread_executor'
  autoload :JavaThreadPoolExecutor, 'concurrent/executor/java_thread_pool_executor'
  autoload :RubyExecutorService, 'concurrent/executor/ruby_executor_service'
  autoload :RubySingleThreadExecutor, 'concurrent/executor/ruby_single_thread_executor'
  autoload :RubyThreadPoolExecutor, 'concurrent/executor/ruby_thread_pool_executor'
  autoload :CachedThreadPool, 'concurrent/executor/cached_thread_pool'
  autoload :SafeTaskExecutor, 'concurrent/executor/safe_task_executor'
  autoload :SerialExecutorService, 'concurrent/executor/serial_executor_service'
  autoload :SerializedExecution, 'concurrent/executor/serialized_execution'
  autoload :SerializedExecutionDelegator, 'concurrent/executor/serialized_execution_delegator'
  autoload :SingleThreadExecutor, 'concurrent/executor/single_thread_executor'
  autoload :ThreadPoolExecutor, 'concurrent/executor/thread_pool_executor'
  autoload :TimerSet, 'concurrent/executor/timer_set'
end

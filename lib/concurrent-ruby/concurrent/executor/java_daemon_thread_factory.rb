module Concurrent

  class DaemonThreadFactory
    include java.util.concurrent.ThreadFactory

    def initialize(daemonize = true)
      @daemonize = daemonize
    end

    def newThread(runnable)
      thread = java.util.concurrent.Executors.defaultThreadFactory().newThread(runnable)
      thread.setDaemon(@daemonize)
      return thread
    end
  end

end
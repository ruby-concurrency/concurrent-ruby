require 'rbconfig'
require 'thread'

module Concurrent

  # Error raised when an operations times out.
  TimeoutError = Class.new(StandardError)

  # Wait the given number of seconds for the block operation to complete.
  #
  # @param [Integer] seconds The number of seconds to wait
  #
  # @return The result of the block operation
  #
  # @raise Concurrent::TimeoutError when the block operation does not complete
  #   in the allotted number of seconds.
  #
  # @note This method is intended to be a simpler and more reliable replacement
  # to the Ruby standard library +Timeout::timeout+ method.
  def timeout(seconds)

    thread = Thread.new do
      Thread.current[:result] = yield
    end
    success = thread.join(seconds)

    if success
      return thread[:result]
    else
      raise TimeoutError
    end
  ensure
    Thread.kill(thread) unless thread.nil?
  end
  module_function :timeout

  # The number of processor cores available on the current system.
  #
  # The number of processor cores on the system may not be the same as the number
  # available to the Ruby runtime. It all depends on what version of Ruby is being
  # run. Not all versions of Ruby can take advantage of more than one core. MRI/CRuby
  # is the worst offender of this.
  #
  # The most accurate measurement is with JRuby where the JVM runtime can be
  # directly queried. In this case the return value will be the exact number of
  # cores available to within the runtime environment. On Windows the Win32 API
  # will be queried for the `NumberOfLogicalProcessors from Win32_Processor`.
  # This will return the total number of logical processors available, taking into
  # account hyperthreading. On Unix-like operating systems either the `hwprefs` or
  # the `sysctl` utility will be called in a subshell and the returned value will
  # be use. In the rare case where none of these methods work the functionw will
  # simply return 1.
  #
  # For performance reasons the calculated value will be memoized on the first call.
  #
  # @return [Integer] the number of processor cores on the host system
  #
  # @see https://github.com/grosser/parallel/blob/master/lib/parallel.rb#L63
  #
  # @see http://msdn.microsoft.com/en-us/library/aa394373(v=vs.85).aspx
  # @see http://www.unix.com/man-page/osx/1/HWPREFS/
  # @see http://linux.die.net/man/8/sysctl
  def processor_count
    @@processor_count ||= if defined? java.lang
                            java.lang.Runtime.getRuntime.availableProcessors
                          else
                            case @host_os
                            when /darwin9/
                              `hwprefs cpu_count`.to_i
                            when /darwin/
                              ((`which hwprefs` != '') ? `hwprefs thread_count` : `sysctl -n hw.ncpu`).to_i
                            when /linux/
                              `cat /proc/cpuinfo | grep processor | wc -l`.to_i
                            when /freebsd/
                              `sysctl -n hw.ncpu`.to_i
                            when /mswin|mingw/
                              require 'win32ole'
                              wmi = WIN32OLE.connect('winmgmts://')
                              cpu = wmi.ExecQuery('select NumberOfLogicalProcessors from Win32_Processor')
                              cpu.to_enum.first.NumberOfCores
                            else
                              1
                            end
                          end
  rescue
    return 1
  end
  module_function :processor_count
end

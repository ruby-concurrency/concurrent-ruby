require 'thread'
require 'functional'

behavior_info(:runnable,
              run: 0,
              stop: 0,
              running?: 0)

module Concurrent

  class Supervisor

    behavior(:runnable)

    DEFAULT_MONITOR_INTERVAL = 1
    RESTART_STRATEGIES = [:one_for_one, :one_for_all, :rest_for_one]
    DEFAULT_MAX_RESTART = 5
    DEFAULT_MAX_TIME = 60

    CHILD_TYPES = [:worker, :supervisor]
    CHILD_RESTART_OPTIONS = [:permanent, :transient, :temporary]

    MaxRestartFrequencyError = Class.new(StandardError)

    WorkerCounts = Struct.new(:specs, :supervisors, :workers) do
      attr_accessor :status
      def add(context)
        self.specs += 1
        self.supervisors += 1 if context.type == :supervisor
        self.workers += 1 if context.type == :worker
      end
      def active() sleeping + running + aborting end;
      def sleeping() @status.reduce(0){|x, s| x += (s == 'sleep' ? 1 : 0) } end;
      def running() @status.reduce(0){|x, s| x += (s == 'run' ? 1 : 0) } end;
      def aborting() @status.reduce(0){|x, s| x += (s == 'aborting' ? 1 : 0) } end;
      def stopped() @status.reduce(0){|x, s| x += (s == false ? 1 : 0) } end;
      def abend() @status.reduce(0){|x, s| x += (s.nil? ? 1 : 0) } end;
    end

    WorkerContext = Struct.new(:worker, :type, :restart) do
      attr_accessor :thread
      def needs_restart?
        return false if @thread && @thread.alive?
        case self.restart
        when :permanent
          return true
        when :transient
          return @thread.nil? || @thread.status.nil?
        else #when :temporary
          return false
        end
      end
    end

    attr_reader :monitor_interval
    attr_reader :restart_strategy
    attr_reader :max_restart
    attr_reader :max_time

    alias_method :strategy, :restart_strategy
    alias_method :max_r, :max_restart
    alias_method :max_t, :max_time

    def initialize(opts = {})
      @restart_strategy = opts[:restart_strategy] || opts[:strategy] || :one_for_one
      @monitor_interval = (opts[:monitor_interval] || DEFAULT_MONITOR_INTERVAL).to_f
      @max_restart = (opts[:max_restart] || opts[:max_r] || DEFAULT_MAX_RESTART).to_i
      @max_time = (opts[:max_time] || opts[:max_t] || DEFAULT_MAX_TIME).to_i

      raise ArgumentError.new(":#{@restart_strategy} is not a valid restart strategy") unless RESTART_STRATEGIES.include?(@restart_strategy)
      raise ArgumentError.new(':monitor_interval must be greater than zero') unless @monitor_interval > 0.0
      raise ArgumentError.new(':max_restart must be greater than zero') unless @max_restart > 0
      raise ArgumentError.new(':max_time must be greater than zero') unless @max_time > 0

      @running = false
      @mutex = Mutex.new
      @workers = []
      @monitor = nil

      @count = WorkerCounts.new(0, 0, 0)
      @restart_times = []

      add_worker(opts[:worker]) unless opts[:worker].nil?
    end

    def run!
      raise StandardError.new('already running') if running?
      @mutex.synchronize do
        @running = true
        @monitor = Thread.new do
          Thread.current.abort_on_exception = false
          monitor
        end
      end
      Thread.pass
    end

    def run
      raise StandardError.new('already running') if running?
      @running = true
      monitor
    end

    def stop
      return true unless running?
      @running = false
      @mutex.synchronize do
        Thread.kill(@monitor) unless @monitor.nil?
        @monitor = nil
        @restart_times.clear

        @workers.length.times do |i|
          context = @workers[-1-i]
          begin
            context.worker.stop
            Thread.pass
          rescue Exception => ex
            # suppress
          ensure
            Thread.kill(context.thread) unless context.thread.nil?
          end
        end
      end
    end

    def running?
      return @running
    end

    def length
      return @workers.length
    end
    alias_method :size, :length

    def current_restart_count
      return @restart_times.length
    end

    def count
      return @mutex.synchronize do
        @count.status = @workers.collect{|w| w.thread ? w.thread.status : false }
        @count.dup.freeze
      end
    end

    def add_worker(worker, opts = {})
      if worker.nil? || running? || ! worker.behaves_as?(:runnable)
        return nil
      else
        return @mutex.synchronize {
          restart = opts[:restart] || :permanent
          type = opts[:type] || (worker.is_a?(Supervisor) ? :supervisor : nil) || :worker
          raise ArgumentError.new(":#{restart} is not a valid restart option") unless CHILD_RESTART_OPTIONS.include?(restart)
          raise ArgumentError.new(":#{type} is not a valid child type") unless CHILD_TYPES.include?(type)
          context = WorkerContext.new(worker, type, restart)
          @workers << context
          @count.add(context)
          context.object_id
        }
      end
    end
    alias_method :add_child, :add_worker

    private

    def monitor
      @workers.each{|context| start_worker(context)}
      loop do
        sleep(@monitor_interval)
        break unless running?
        @mutex.synchronize do
          self.send(@restart_strategy)
        end
        break unless running?
      end
    rescue MaxRestartFrequencyError => ex
      stop
    end

    def start_worker(context)
      context.thread = Thread.new do
        Thread.current.abort_on_exception = false
        context.worker.run
      end
      return context
    end

    def exceeded_max_restart_frequency?
      @restart_times.unshift(Time.now.to_i)
      diff = delta(@restart_times.first, @restart_times.last)
      if @restart_times.length >= @max_restart && diff <= @max_time
        return true
      elsif diff >= @max_time
        @restart_times.pop
      end
      return false
    end

    def one_for_one
      @workers.each do |context|
        if context.needs_restart?
          raise MaxRestartFrequencyError if exceeded_max_restart_frequency?
          start_worker(context)
        end
      end
    end

    def one_for_all
      restart = false

      restart = @workers.each do |context|
        if context.needs_restart?
          raise MaxRestartFrequencyError if exceeded_max_restart_frequency?
          break(true)
        end
      end

      if restart

        @workers.each do |context|
          begin
            context.worker.stop
          rescue Exception => ex
            # suppress
          end
        end

        @workers.each{|context| start_worker(context)}
      end
    end

    def rest_for_one
      restart = false

      @workers.each do |context|
        if restart
          begin
            context.worker.stop
          rescue Exception => ex
            # suppress
          end
        elsif context.needs_restart?
          raise MaxRestartFrequencyError if exceeded_max_restart_frequency?
          restart = true
        end
      end

      one_for_one if restart
    end
  end
end

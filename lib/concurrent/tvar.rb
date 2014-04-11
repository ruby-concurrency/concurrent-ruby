require 'set'

require 'concurrent/atomic/thread_local_var'

module Concurrent

  ABORTED = Object.new

  CURRENT_TRANSACTION = ThreadLocalVar.new(nil)

  ReadLogEntry = Struct.new(:tvar, :version)
  UndoLogEntry = Struct.new(:tvar, :value)

  class TVar

    def initialize(value)
      @value = value
      @version = 0
      @lock = Mutex.new
    end

    def value
      Concurrent::atomically do
        Transaction::current.read(self)
      end
    end

    def value=(value)
      Concurrent::atomically do
        Transaction::current.write(self, value)
      end
    end

    def unsafe_value
      @value
    end

    def unsafe_value=(value)
      @value = value
    end

    def unsafe_version
      @version
    end

    def unsafe_increment_version
      @version += 1
    end

    def unsafe_lock
      @lock
    end

  end

  class Transaction

    def initialize
      @write_set = Set.new
      @read_log = []
      @undo_log = []
    end

    def read(tvar)
      Concurrent::abort_transaction unless valid?
      @read_log.push(ReadLogEntry.new(tvar, tvar.unsafe_version))
      tvar.unsafe_value
    end

    def write(tvar, value)
      # Have we already written to this TVar?

      unless @write_set.include? tvar
        # Try to lock the TVar

        unless tvar.unsafe_lock.try_lock
          # Someone else is writing to this TVar - abort
          Concurrent::abort_transaction
        end

        # We've locked it - add it to the write set

        @write_set.add(tvar)

        # If we previously wrote to it, check the version hasn't changed

        @read_log.each do |log_entry|
          if log_entry.tvar == tvar and tvar.unsafe_version > log_entry.version
            Concurrent::abort_transaction
          end
        end
      end

      # Record the current value of the TVar so we can undo it later

      @undo_log.push(UndoLogEntry.new(tvar, tvar.unsafe_value))

      # Write the new value to the TVar

      tvar.unsafe_value = value
    end

    def abort
      @undo_log.each do |entry|
        entry.tvar.unsafe_value = entry.value
      end

      unlock
    end

    def commit
      return false unless valid?

      @write_set.each do |tvar|
        tvar.unsafe_increment_version
      end

      unlock
      
      true
    end

    def valid?
      @read_log.each do |log_entry|
        unless @write_set.include? log_entry.tvar
          if log_entry.tvar.unsafe_version > log_entry.version
            return false
          end
        end
      end

      true
    end

    def unlock
      @write_set.each do |tvar|
        tvar.unsafe_lock.unlock
      end
    end

    def self.current
      CURRENT_TRANSACTION.value
    end

    def self.current=(transaction)
      CURRENT_TRANSACTION.value = transaction
    end

  end

  AbortError = Class.new(StandardError)

  def atomically
    raise ArgumentError.new('no block given') unless block_given?

    # Get the current transaction

    transaction = Transaction::current

    # Are we not already in a transaction (not nested)?

    if transaction.nil?
      # New transaction

      begin
        # Retry loop
        
        loop do

          # Create a new transaction

          transaction = Transaction.new
          Transaction::current = transaction

          # Run the block, aborting on exceptions

          begin
            result = yield
          rescue AbortError => e
            transaction.abort
            result = ABORTED
          rescue => e
            transaction.abort
            throw e
          end
          # If we can commit, break out of the loop

          if result != ABORTED
            if transaction.commit
              break result
            end
          end
        end
      ensure
        # Clear the current transaction

        Transaction::current = nil
      end
    else
      # Nested transaction - flatten it and just run the block

      yield
    end
  end

  def abort_transaction
    raise AbortError.new
  end

  module_function :atomically, :abort_transaction

end

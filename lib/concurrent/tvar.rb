module Concurrent

  ABORTED = Object.new

  class TVar

    def initialize(value)
      @value = value
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

  end

  UndoLogEntry = Struct.new(:tvar, :value)

  class Transaction

    LOCK = Mutex.new

    def initialize
      @undo_log = []

      LOCK.lock
    end

    def read(tvar)
      validate
      tvar.unsafe_value
    end

    def write(tvar, value)
      @undo_log.push(UndoLogEntry.new(tvar, tvar.unsafe_value))
      tvar.unsafe_value = value
    end

    def abort
      @undo_log.each do |entry|
        entry.tvar.unsafe_value = entry.value
      end

      unlock
    end

    def commit
      validate
      unlock
      true
    end

    def validate
    end

    def unlock
      LOCK.unlock
    end

    def self.current
      Thread.current.thread_variable_get(:transaction)
    end

    def self.current=(transaction)
      Thread.current.thread_variable_set(:transaction, transaction)
    end

  end

  class AbortException < Exception
  end

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
          rescue AbortException => e
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
    raise AbortException.new
  end

  module_function :atomically, :abort_transaction

end

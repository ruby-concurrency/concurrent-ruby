require 'monitor'
require 'concurrent'

class UnsynchronizedBank

  def initialize(account_totals)
    @accounts = account_totals.dup
  end

  def transfer(from, to, sum)
    if @accounts[from] < sum
      false
    else
      @accounts[from] -= sum
      @accounts[to] += sum
      true
    end
  end

  def grand_total
    @accounts.inject(0, :+)
  end

end

class CoarseLockBank

  def initialize(account_totals)
    @accounts = account_totals.dup
    @lock = Mutex.new
  end

  def transfer(from, to, sum)
    @lock.synchronize do
      if @accounts[from] < sum
        false
      else
        @accounts[from] -= sum
        @accounts[to] += sum
        true
      end
    end
  end

  def grand_total
    @accounts.inject(0, :+)
  end

end

class FineLockBank

  Account = Struct.new(:lock, :value)

  def initialize(account_totals)
    @accounts = account_totals.map do |v|
      Account.new(Monitor.new, v)
    end
  end

  def transfer(from, to, sum)
    locks = [@accounts[from].lock, @accounts[to].lock]
    ordered_locks = locks.sort{ |a, b| a.object_id <=> b.object_id }

    ordered_locks[0].synchronize do
      ordered_locks[1].synchronize do
        if @accounts[from].value < sum
          false
        else
          @accounts[from].value -= sum
          @accounts[to].value += sum
          true
        end
      end
    end
  end

  def grand_total
    @accounts.map(&:value).inject(0, :+)
  end

end

class TransactionalBank

  def initialize(account_totals)
    @accounts = account_totals.map do |v|
      Concurrent::TVar.new(v)
    end
  end

  def transfer(from, to, sum)
    Concurrent::atomically do
      if @accounts[from].value < sum
        false
      else
        @accounts[from].value -= sum
        @accounts[to].value += sum
        true
      end
    end
  end

  def grand_total
    @accounts.map(&:value).inject(0, :+)
  end

end

RANDOM = Random.new(0)

Transfer = Struct.new(:from, :to, :sum)

ACCOUNT_TOTALS = (0..100_000).map do
  RANDOM.rand(100)
end

GRAND_TOTAL = ACCOUNT_TOTALS.inject(0, :+)

TRANSFERS = (0..10_000_000).map do
  Transfer.new(
    RANDOM.rand(ACCOUNT_TOTALS.size),
    RANDOM.rand(ACCOUNT_TOTALS.size),
    RANDOM.rand(100))
end

THREADS = 8
TRANSFER_PER_THREAD = TRANSFERS.size / THREADS

def test(bank_class)
  puts bank_class
  bank = bank_class.new(ACCOUNT_TOTALS)

  puts "total before: #{bank.grand_total}"

  start = Time.now

  (1..THREADS).map { |n|
    Thread.new do
      TRANSFERS[(n*TRANSFER_PER_THREAD)..((n+1)*TRANSFER_PER_THREAD)].each do |transfer|
        bank.transfer(transfer.from, transfer.to, transfer.sum)
      end
    end
  }.each(&:join)

  puts "total after:  #{bank.grand_total}"
  puts "took #{Time.now - start}s"
end

test UnsynchronizedBank
test CoarseLockBank
test FineLockBank
test TransactionalBank

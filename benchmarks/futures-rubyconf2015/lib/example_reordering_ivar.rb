class ACLass
  attr_reader :value

  def initialize(value)
    @value = value # 1
  end
end

instance = nil

Thread.new do
  raise if instance.value.nil? # may raise
end

instance = ACLass.new(42) # 2

puts instance.value # 3: prints always 42



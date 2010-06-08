require 'test/unit'
require 'atomic'

class TestAtomic < Test::Unit::TestCase
  def test_construct
    atomic = Atomic.new
    assert_equal nil, atomic.value
    
    atomic = Atomic.new(0)
    assert_equal 0, atomic.value
  end
  
  def test_value
    atomic = Atomic.new(0)
    atomic.value = 1
    
    assert_equal 1, atomic.value
  end
  
  def test_update
    atomic = Atomic.new(0)
    atomic.update {|v| v + 1}
    
    assert_equal 1, atomic.value
  end
  
  def test_try_update
    atomic = Atomic.new(0)
    atomic.try_update {|v| v + 1}
    
    assert_equal 1, atomic.value
  end
  
  # TODO: Test the ConcurrentUpdateError cases
end
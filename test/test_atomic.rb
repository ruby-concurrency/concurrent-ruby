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
    # use a number outside JRuby's fixnum cache range, to ensure identity is preserved
    atomic = Atomic.new(1000)
    res = atomic.update {|v| v + 1}
    
    assert_equal 1001, atomic.value
    assert_equal 1001, res
  end
  
  def test_try_update
    # use a number outside JRuby's fixnum cache range, to ensure identity is preserved
    atomic = Atomic.new(1000)
    res = atomic.try_update {|v| v + 1}
    
    assert_equal 1001, atomic.value
    assert_equal 1001, res
  end

  def test_swap
    atomic = Atomic.new(1000)
    res = atomic.swap(1001)

    assert_equal 1001, atomic.value
    assert_equal 1000, res
  end
  
  def test_try_update_fails
    # use a number outside JRuby's fixnum cache range, to ensure identity is preserved
    atomic = Atomic.new(1000)
    assert_raise Atomic::ConcurrentUpdateError do
      # assigning within block exploits implementation detail for test
      atomic.try_update{|v| atomic.value = 1001 ; v + 1}
    end
  end

  def test_update_retries
    tries = 0
    # use a number outside JRuby's fixnum cache range, to ensure identity is preserved
    atomic = Atomic.new(1000)
    # assigning within block exploits implementation detail for test
    atomic.update{|v| tries += 1 ; atomic.value = 1001 ; v + 1}
    assert_equal 2, tries
  end
end

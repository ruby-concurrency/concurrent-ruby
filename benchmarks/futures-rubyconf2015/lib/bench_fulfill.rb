ITERATIONS = 2_500_000

def harness_input
end

def harness_sample(input)
  last_future = nil
  ITERATIONS.times do |i|
    last_future = FutureImplementation.new
    last_future.fulfill i
  end
  last_future
end

def harness_verify(output)
  output.value == ITERATIONS - 1
end

require 'bench9000/harness'


ITERATIONS = 5_000_000

def harness_input
  f = FutureImplementation.new
  f.fulfill 1
  f
end

def harness_sample(input)
  sum = 0

  ITERATIONS.times do
    sum += input.value
  end

  sum
end

def harness_verify(output)
  output == ITERATIONS
end

require 'bench9000/harness'


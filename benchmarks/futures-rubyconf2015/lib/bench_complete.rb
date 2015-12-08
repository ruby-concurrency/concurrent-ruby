ITERATIONS = 2_500_000

def harness_input
  FutureImplementation.new
end

def harness_sample(input)
  ITERATIONS.times do
    input.complete?
  end

  input.fulfill true

  ITERATIONS.times do
    input.complete?
  end
end

def harness_verify(output)
  true
end

require 'bench9000/harness'

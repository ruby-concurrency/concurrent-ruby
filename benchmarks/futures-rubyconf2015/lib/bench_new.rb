
ITERATIONS = 2_500_000

def harness_input
end

def harness_sample(input)
  last = nil
  ITERATIONS.times do |i|
    last = FutureImplementation.new
  end
  last
end

def harness_verify(output)
  output.is_a? FutureImplementation
end

require 'bench9000/harness'


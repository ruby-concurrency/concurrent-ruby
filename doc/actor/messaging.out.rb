require 'algebrick'                                # => true

# Actor message protocol definition with Algebrick
Protocol = Algebrick.type do
  variants Add      = type { fields! a: Numeric, b: Numeric },
           Subtract = type { fields! a: Numeric, b: Numeric }
end                                                # => Protocol(Add | Subtract)

class Calculator < Concurrent::Actor::RestartingContext
  include Algebrick::Matching

  def on_message(message)
    # pattern matching on the message with deconstruction
    # ~ marks values which are passed to the block
    match message,
          (on Add.(~any, ~any) do |a, b|
            a + b
          end),
          # or using multi-assignment
          (on ~Subtract do |(a, b)|
            a - b
          end)
  end
end 

calculator = Calculator.spawn('calculator')
    # => #<Concurrent::Actor::Reference:0x7ff3ab0c4f80 /calculator (Calculator)>
addition = calculator.ask Add[1, 2]
    # => <#Concurrent::Edge::Future:0x7ff3ab08e188 pending blocks:[]>
substraction = calculator.ask Subtract[1, 0.5]
    # => <#Concurrent::Edge::Future:0x7ff3ab9de940 pending blocks:[]>
results = (addition & substraction)
    # => <#Concurrent::Edge::Future:0x7ff3aa0b1b48 pending blocks:[]>
results.value!                                     # => [3, 0.5]

calculator.ask! :terminate!                        # => true

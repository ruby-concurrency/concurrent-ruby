require 'concurrent'

Array.new(4) do 
  Concurrent.zip(
    Array.new(5) do |i|
      Concurrent::Delay.new do 
        puts "starting #{i}"
        sleep(i)
        puts "done #{i}"
        i
      end
    end
  )
end.inject { |a,b| a.chain { b }.flat }.value!

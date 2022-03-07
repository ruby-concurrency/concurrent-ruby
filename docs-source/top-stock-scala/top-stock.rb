require 'concurrent'
require 'csv'
require 'open-uri'

def get_year_end_closing(symbol, year, api_key)
  uri = "https://www.alphavantage.co/query?function=TIME_SERIES_MONTHLY&symbol=#{symbol}&apikey=#{api_key}&datatype=csv"
  data = []
  open(uri) do |f|
    CSV.parse(f, headers: true) do |row|
      data << row['close'] if row['timestamp'].include?(year.to_s)
    end
  end
  price = data.max
  price.to_f
  [symbol, price.to_f]
end

def get_top_stock(symbols, year, timeout = 10)
  api_key = ENV['ALPHAVANTAGE_KEY']
  abort(error_message) unless api_key

  stock_prices = symbols.collect{|symbol| Concurrent::dataflow{ get_year_end_closing(symbol, year, api_key) }}
  Concurrent::dataflow(*stock_prices) { |*prices|
    prices.reduce(['', 0.0]){|highest, price| price.last > highest.last ? price : highest}
  }.value(timeout)
end

def error_message
  <<~EOF
    PLEASE provide a Alpha Vantage api key for the example to work
    usage:
      ALPHAVANTAGE_KEY=YOUR_API_KEY bundle exec ruby top-stock-scala/top-stock.rb
  EOF
end

symbols = ['AAPL', 'GOOG', 'IBM', 'ORCL', 'MSFT']
year = 2008

top_stock, highest_price = get_top_stock(symbols, year)

puts "Top stock of #{year} is #{top_stock} closing at price $#{highest_price}"

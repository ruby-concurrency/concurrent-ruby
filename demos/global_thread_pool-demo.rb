require 'concurrent'
require 'open-uri'

def get_year_end_closing(symbol, year)
  uri = "http://ichart.finance.yahoo.com/table.csv?s=#{symbol}&a=11&b=01&c=#{year}&d=11&e=31&f=#{year}&g=m"
  data = open(uri) {|f| f.collect{|line| line.strip } }
  price = data[1].split(',')[4]
  price.to_f
  [symbol, price.to_f]
end

def get_top_stock(symbols, year, timeout = 5)
  stock_prices = symbols.collect{|symbol| Concurrent::dataflow{ get_year_end_closing(symbol, year) }}
  Concurrent::dataflow(*stock_prices) { |*prices|
    prices.reduce(['', 0.0]){|highest, price| price.last > highest.last ? price : highest}
  }.value(timeout)
end

def timer(*args)
  return 0,nil unless block_given?
  t1 = Time.now
  result = yield(*args)
  t2 = Time.now
  return (t2 - t1), result
end

def strftimer(seconds) # :nodoc:
  Time.at(seconds).gmtime.strftime('%R:%S.%L')
end

s_and_p_500 = ['MMM','ABT','ABBV','ACE','ACN','ACT','ADBE','ADT','AES','AET','AFL','A','GAS','APD','ARG','AKAM','AA','ALXN','ATI','ALLE','AGN','ADS','ALL','ALTR','MO','AMZN','AEE','AEP','AXP','AIG','AMT','AMP','ABC','AME','AMGN','APH','APC','ADI','AON','APA','AIV','AAPL','AMAT','ADM','AIZ','T','ADSK','ADP','AN','AZO','AVB','AVY','AVP','BHI','BLL','BAC','BK','BCR','BAX','BBT','BEAM','BDX','BBBY','BMS','BRK.B','BBY','BIIB','BLK','HRB','BA','BWA','BXP','BSX','BMY','BRCM','BF.B','CHRW','CA','CVC','COG','CAM','CPB','COF','CAH','CFN','KMX','CCL','CAT','CBG','CBS','CELG','CNP','CTL','CERN','CF','SCHW','CHK','CVX','CMG','CB','CI','CINF','CTAS','CSCO','C','CTXS','CLF','CLX','CME','CMS','COH','KO','CCE','CTSH','CL','CMCSA','CMA','CSC','CAG','COP','CNX','ED','STZ','GLW','COST','COV','CCI','CSX','CMI','CVS','DHI','DHR','DRI','DVA','DE','DLPH','DAL','DNR','XRAY','DVN','DO','DTV','DFS','DISCA','DG','DLTR','D','DOV','DOW','DPS','DTE','DD','DUK','DNB','ETFC','EMN','ETN','EBAY','ECL','EIX','EW','EA','EMC','EMR','ESV','ETR','EOG','EQT','EFX','EQR','EL','EXC','EXPE','EXPD','ESRX','XOM','FFIV','FB','FDO','FAST','FDX','FIS','FITB','FSLR','FE','FISV','FLIR','FLS','FLR','FMC','FTI','F','FRX','FOSL','BEN','FCX','FTR','GME','GCI','GPS','GRMN','GD','GE','GGP','GIS','GM','GPC','GNW','GILD','GS','GT','GOOG','GWW','HAL','HOG','HAR','HRS','HIG','HAS','HCP','HCN','HP','HES','HPQ','HD','HON','HRL','HSP','HST','HCBK','HUM','HBAN','ITW','IR','TEG','INTC','ICE','IBM','IGT','IP','IPG','IFF','INTU','ISRG','IVZ','IRM','JBL','JEC','JNJ','JCI','JOY','JPM','JNPR','KSU','K','KEY','GMCR','KMB','KIM','KMI','KLAC','KSS','KRFT','KR','LB','LLL','LH','LRCX','LM','LEG','LEN','LUK','LLY','LNC','LLTC','LMT','L','LO','LOW','LSI','LYB','MTB','MAC','M','MRO','MPC','MAR','MMC','MAS','MA','MAT','MKC','MCD','MHFI','MCK','MJN','MWV','MDT','MRK','MET','MCHP','MU','MSFT','MHK','TAP','MDLZ','MON','MNST','MCO','MS','MOS','MSI','MUR','MYL','NBR','NDAQ','NOV','NTAP','NFLX','NWL','NFX','NEM','NWSA','NEE','NLSN','NKE','NI','NE','NBL','JWN','NSC','NTRS','NOC','NU','NRG','NUE','NVDA','KORS','ORLY','OXY','OMC','OKE','ORCL','OI','PCG','PCAR','PLL','PH','PDCO','PAYX','BTU','PNR','PBCT','POM','PEP','PKI','PRGO','PETM','PFE','PM','PSX','PNW','PXD','PBI','PCL','PNC','RL','PPG','PPL','PX','PCP','PCLN','PFG','PG','PGR','PLD','PRU','PEG','PSA','PHM','PVH','QEP','PWR','QCOM','DGX','RRC','RTN','RHT','REGN','RF','RSG','RAI','RHI','ROK','COL','ROP','ROST','RDC','R','SWY','CRM','SNDK','SCG','SLB','SNI','STX','SEE','SRE','SHW','SIAL','SPG','SLM','SJM','SNA','SO','LUV','SWN','SE','STJ','SWK','SPLS','SBUX','HOT','STT','SRCL','SYK','STI','SYMC','SYY','TROW','TGT','TEL','TE','THC','TDC','TSO','TXN','TXT','HSY','TRV','TMO','TIF','TWX','TWC','TJX','TMK','TSS','TSCO','RIG','TRIP','FOXA','TSN','TYC','USB','UNP','UNH','UPS','X','UTX','UNM','URBN','VFC','VLO','VAR','VTR','VRSN','VZ','VRTX','VIAB','V','VNO','VMC','WMT','WAG','DIS','GHC','WM','WAT','WLP','WFC','WDC','WU','WY','WHR','WFM','WMB','WIN','WEC','WYN','WYNN','XEL','XRX','XLNX','XL','XYL','YHOO','YUM','ZMH','ZION','ZTS']
year = 2013

#puts "Starting the sequential calculation..."
#time, prices = timer do
  #s_and_p_500.inject({}){|memo, symbol| memo[symbol] = get_year_end_closing(symbol, year).last; memo }
#end
#puts "Sequential time: #{strftimer(time)}"

puts "Starting the concurrent calculation..."
time, prices = timer do
  futures = s_and_p_500.collect{|symbol| Concurrent::Future.execute{ get_year_end_closing(symbol, year) } }
  futures.inject({}){|memo, future| memo[future.value.first] = future.value.last; memo }
end
puts "Concurrent time: #{strftimer(time)}"

future_benchmarks = [
    'mutex-complete',
    'mutex-value',
    'mutex-fulfill',
    'special-complete',
    'special-value',
    'special-fulfill',
    'cr-complete',
    'cr-value',
    'cr-fulfill',
    'cr-cas-complete',
    'cr-cas-value',
    'cr-cas-fulfill',
]

future_new_benchmarks = [
    'cr-cas-new',
    'cr-new',
    'special-new'
]

all_bechmarks = future_benchmarks + future_new_benchmarks

all_bechmarks.each do |name|
  benchmark "future-#{name}",
            "#{default_benchmarks_dir}/futures-rubyconf2015/benchmarks/#{name}.rb",
            "-I #{default_benchmarks_dir}/futures-rubyconf2015/lib"
end

benchmark_group 'future', *(future_benchmarks.map { |v| "future-#{v}" })
benchmark_group 'future-new', *(all_bechmarks.map { |v| "future-#{v}" })

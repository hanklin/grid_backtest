# backtest_main.rb
# frozen_string_literal: true

require_relative './backtest_cli_options'
require_relative './binance_price_client'
require_relative './band_estimators'
require_relative './grid_backtester'
require_relative './backtest_reporter'
require_relative './stats_utils'

include StatsUtils

opts   = BacktestCliOptions.parse!
symbol = opts[:symbol]
debug  = opts[:debug]

price_timeframe = opts[:price_timeframe]

client = BinancePriceClient.new(debug: debug)

# timeframe -> 一天有幾根
timeframe_minutes =
  case price_timeframe
  when '1m'  then 1
  when '5m'  then 5
  when '15m' then 15
  when '1h'  then 60
  when '4h'  then 240
  when '1d'  then 1440
  else
    warn "Unknown timeframe #{price_timeframe}, fallback to 15m"
    price_timeframe = '15m'
    15
  end

candles_per_day = (24 * 60) / timeframe_minutes

window_size_days  = opts[:window_size_days]
max_windows       = opts[:max_windows]
window_slide_days = opts[:window_slide_days]

# 需要的總天數 = 主視窗 + 往前滑的部份
total_days   = window_size_days + (max_windows - 1) * window_slide_days
total_candles_needed = total_days * candles_per_day

raw_klines = client.fetch_recent_klines(
  symbol:  symbol,
  interval: price_timeframe,
  limit:   total_candles_needed
)

all_closes = raw_klines.map { |k| k[:close] }

min_needed_for_one_window = window_size_days * candles_per_day
if all_closes.size < min_needed_for_one_window
  warn "資料不足: symbol=#{symbol}, 需要至少 #{min_needed_for_one_window} 根 K 線，實際只有 #{all_closes.size} 根"
  exit 1
end

windows_results = []

# 從最新往回切 window
max_windows.times do |i|
  end_idx   = all_closes.size - i * window_slide_days * candles_per_day
  start_idx = end_idx - window_size_days * candles_per_day

  next if start_idx < 0 || end_idx <= start_idx

  window_prices = all_closes[start_idx...end_idx]
  next if window_prices.size < 10

  vol_stats = BandEstimators.window_vol_stats(window_prices)

  band_types =
    case opts[:band_type]
    when 'simple' then ['simple']
    when 'robust' then ['robust']
    else ['simple', 'robust']
    end

  band_types.each do |band_type|
    band =
      case band_type
      when 'simple'
        BandEstimators.simple_quantile_band(
          window_prices,
          low_q:  0.05,
          high_q: 0.95
        )
      when 'robust'
        BandEstimators.robust_band(
          window_prices,
          low_q:        0.20,
          high_q:       0.80,
          outlier_sigma: 3.0,
          trim_frac:    0.05
        )
      end

    next unless band

    lower = band[:grid_lower_price]
    upper = band[:grid_upper_price]
    next unless lower && upper && lower > 0.0 && upper > lower

    grid_results = []
    min_g = opts[:min_number_of_grids]
    max_g = opts[:max_number_of_grids]
    step  = [opts[:grid_count_step].to_i, 1].max

    (min_g..max_g).step(step).each do |g|
      res = GridBacktester.backtest_window(
        grid_lower_price: lower,
        grid_upper_price: upper,
        number_of_grids:  g,
        fee_rate:         opts[:fee_rate],
        price_series:     window_prices,
        window_days:      window_size_days,
        vol_stats:        vol_stats
      )
      grid_results << res if res
    end

    if grid_results.any?
      best_total = grid_results.max_by { |gr| gr[:total_net_return_pct] || -Float::INFINITY }
      best_pairs = grid_results.max_by { |gr| gr[:number_of_matching_pairs] || 0 }

      grid_results.each do |gr|
        gr[:best_by_total_net] = gr.equal?(best_total)
        gr[:best_by_pairs]     = gr.equal?(best_pairs)
      end
    end

    windows_results << {
      window_index:          i,
      band_type:             band_type,
      window_start_time_ms:  raw_klines[start_idx][:open_time],
      window_end_time_ms:    raw_klines[end_idx - 1][:close_time],
      band:                  band,
      vol_stats:             vol_stats,
      grid_results:          grid_results
    }
  end
end

BacktestReporter.print_results(
  symbol:          symbol,
  opts:            opts,
  windows_results: windows_results
)

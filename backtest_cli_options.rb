# backtest_cli_options.rb
# frozen_string_literal: true

require 'optparse'

module BacktestCliOptions
  module_function

  DEFAULTS = {
    window_size_days:       60,
    max_windows:            4,
    window_slide_days:      nil, # 若為 nil -> window_size_days / 2
    min_number_of_grids:    35,
    max_number_of_grids:    170,
    grid_count_step:        1,     # number_of_grids 增加量
    fee_rate:               0.00075,
    band_type:              'both', # simple / robust / both
    price_timeframe:        '15m',
    debug:                  false
  }.freeze

  def parse!(argv = ARGV)
    opts = DEFAULTS.dup
    opts[:symbol] = nil

    parser = OptionParser.new do |o|
      o.banner = "Usage: ruby backtest_main.rb --symbol BTCUSDT [options]"

      o.on('--symbol SYMBOL', '交易對 symbol，例如 BTCUSDT') do |v|
        opts[:symbol] = v
      end

      o.on('--window-size-days N', Integer, "單一回測視窗天數（預設 #{DEFAULTS[:window_size_days]}）") do |v|
        opts[:window_size_days] = v
      end

      o.on('--max-windows N', Integer, "回測視窗個數（預設 #{DEFAULTS[:max_windows]}）") do |v|
        opts[:max_windows] = v
      end

      o.on('--window-slide-days N', Integer, '視窗滑動天數（預設為 window_size_days/2）') do |v|
        opts[:window_slide_days] = v
      end

      o.on('--min-number-of-grids N', Integer, "最小格數（預設 #{DEFAULTS[:min_number_of_grids]}）") do |v|
        opts[:min_number_of_grids] = v
      end

      o.on('--max-number-of-grids N', Integer, "最大格數（預設 #{DEFAULTS[:max_number_of_grids]}）") do |v|
        opts[:max_number_of_grids] = v
      end

      o.on('--grid-count-step N', Integer, "格數增加量（預設 #{DEFAULTS[:grid_count_step]}）") do |v|
        opts[:grid_count_step] = v
      end

      o.on('--fee-rate F', Float, "手續費比率（預設 #{DEFAULTS[:fee_rate]}）") do |v|
        opts[:fee_rate] = v
      end

      o.on('--band-type TYPE', String, "band 類型：simple / robust / both（預設 both）") do |v|
        opts[:band_type] = v.downcase
      end

      o.on('--price-timeframe TF', String, "K 線時間，例如 15m / 1h（預設 #{DEFAULTS[:price_timeframe]}）") do |v|
        opts[:price_timeframe] = v
      end

      o.on('--debug', '顯示 debug 訊息') do
        opts[:debug] = true
      end

      o.on('-h', '--help', 'Show this help') do
        puts o
        exit
      end
    end

    parser.parse!(argv)

    abort "Missing --symbol" if opts[:symbol].nil? || opts[:symbol].empty?

    opts[:window_slide_days] ||= (opts[:window_size_days] / 2.0).round

    opts
  end
end

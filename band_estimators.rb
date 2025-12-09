# band_estimators.rb
# frozen_string_literal: true

require_relative './stats_utils'

module BandEstimators
  include StatsUtils
  module_function

  # simple quantile band：直接用 quantile
  # 回傳：
  # {
  #   grid_lower_price:,
  #   grid_upper_price:,
  #   center_price:,
  #   band_width_pct:
  # }
  def simple_quantile_band(price_series, low_q: 0.05, high_q: 0.95)
    prices = price_series.map { |p| StatsUtils.to_f(p) }.select { |p| p > 0.0 }
    return nil if prices.size < 10

    low  = StatsUtils.quantile(prices, low_q)
    high = StatsUtils.quantile(prices, high_q)
    lower, upper = [low, high].minmax
    center = (lower + upper) / 2.0
    return nil if center <= 0.0
    width_pct = (upper - lower) / center * 100.0

    {
      grid_lower_price: lower,
      grid_upper_price: upper,
      center_price:     center,
      band_width_pct:   width_pct
    }
  end

  # robust_band：加上 z-score 過濾 + trimming 再 quantile
  def robust_band(price_series,
                  low_q: 0.2,
                  high_q: 0.8,
                  outlier_sigma: 3.0,
                  trim_frac: 0.05)
    prices = price_series.map { |p| StatsUtils.to_f(p) }.select { |p| p > 0.0 }
    return nil if prices.size < 50

    # 用 log-returns 做 z-score
    rets = StatsUtils.log_returns(prices)
    mu = rets.size > 0 ? (rets.sum / rets.size.to_f) : 0.0
    sd = StatsUtils.stdev(rets)

    keep = Array.new(prices.size, true)
    if sd > 0.0
      rets.each_with_index do |r, i|
        z = (r - mu).abs / sd
        keep[i + 1] = false if z > outlier_sigma
      end
    end
    filtered = prices.each_with_index.map { |p, i| keep[i] ? p : nil }.compact
    return nil if filtered.size < 30

    # trimming
    sorted = filtered.sort
    trim = (trim_frac * sorted.size).floor
    core =
      if trim > 0 && sorted.size > 2 * trim + 10
        sorted[trim..-(trim + 1)]
      else
        sorted
      end

    low  = StatsUtils.quantile(core, low_q)
    high = StatsUtils.quantile(core, high_q)
    lower, upper = [low, high].minmax
    center = (lower + upper) / 2.0
    return nil if center <= 0.0
    width_pct = (upper - lower) / center * 100.0

    {
      grid_lower_price: lower,
      grid_upper_price: upper,
      center_price:     center,
      band_width_pct:   width_pct
    }
  end

  # window 的波動指標（15m）
  # 回傳：
  # {
  #   sigma_15m_return_pct:,
  #   median_abs_15m_return_pct:
  # }
  def window_vol_stats(price_series)
    {
      sigma_15m_return_pct:       StatsUtils.sigma_15m_return_pct(price_series),
      median_abs_15m_return_pct:  StatsUtils.median_abs_15m_return_pct(price_series)
    }
  end
end

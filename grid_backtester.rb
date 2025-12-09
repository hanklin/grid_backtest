# grid_backtester.rb
# frozen_string_literal: true

require_relative './stats_utils'

module GridBacktester
  include StatsUtils
  module_function

  # 幾何網格：計算「跨越格線的次數」
  # price_series: [Float] 單一 window 的 close 價
  def count_triggers_geometric(price_series, lower, upper, number_of_grids)
    g = number_of_grids.to_i
    lower = StatsUtils.to_f(lower)
    upper = StatsUtils.to_f(upper)
    return 0 if g <= 0 || lower <= 0.0 || upper <= lower

    prices = price_series.map { |p| StatsUtils.to_f(p) }.compact
    return 0 if prices.size < 2

    ratio_step = (upper / lower) ** (1.0 / g.to_f)
    step_log = Math.log(ratio_step)
    return 0.0 if step_log <= 0.0

    clamp = lambda do |p|
      return lower if p <= lower
      return upper if p >= upper
      p
    end

    idx_of = lambda do |p|
      p = clamp.call(p)
      i = (Math.log(p / lower) / step_log).floor
      i = 0 if i < 0
      i = g if i > g
      i
    end

    prev_idx = idx_of.call(prices.first)
    triggers = 0
    prices[1..-1].each do |px|
      idx = idx_of.call(px)
      d = (idx - prev_idx).abs
      triggers += d if d > 0
      prev_idx = idx
    end
    triggers
  end

  # 單一 window + 單一 number_of_grids 的回測
  # price_series: [Float] window 內的 close 價（時間排序）
  # window_days: 此 window 涵蓋天數（例如 60）
  # vol_stats: { sigma_15m_return_pct:, median_abs_15m_return_pct: }
  #
  # 回傳 hash：
  # {
  #   number_of_grids:,
  #   grid_step_pct:,
  #   number_of_matching_pairs:,
  #   theoretical_net_return_per_cycle_pct:,
  #   realized_avg_net_return_per_cycle_pct:,
  #   total_net_return_pct:,
  #   theoretical_net_return_per_day_pct:,
  #   step_to_sigma_ratio:,
  #   sigma_15m_return_pct:,
  #   median_abs_15m_return_pct:
  # }
  def backtest_window(grid_lower_price:,
                      grid_upper_price:,
                      number_of_grids:,
                      fee_rate:,
                      price_series:,
                      window_days:,
                      vol_stats: {})
    prices = price_series.map { |p| StatsUtils.to_f(p) }.compact
    return nil if prices.size < 2

    lower = StatsUtils.to_f(grid_lower_price)
    upper = StatsUtils.to_f(grid_upper_price)
    return nil if lower <= 0.0 || upper <= lower

    g = number_of_grids.to_i
    return nil if g <= 0

    # grid step (%)
    ratio_step = (upper / lower) ** (1.0 / g.to_f)
    grid_step_pct = (ratio_step - 1.0) * 100.0

    # 估計觸發次數
    triggers = count_triggers_geometric(prices, lower, upper, g)
    matching_pairs = (triggers / 2).floor

    # 理論每 cycle 淨報酬（小數 → 轉百分比）
    net_per_cycle_dec = StatsUtils.geometric_grid_profit_pct(
      lower: lower,
      upper: upper,
      grids: g,
      fee_rate: fee_rate
    )
    theoretical_net_return_per_cycle_pct = net_per_cycle_dec * 100.0

    total_net_return_pct = matching_pairs * theoretical_net_return_per_cycle_pct
    realized_avg_net_return_per_cycle_pct =
      matching_pairs > 0 ? (total_net_return_pct / matching_pairs.to_f) : 0.0

    theoretical_net_return_per_day_pct =
      window_days.to_f > 0 ? (total_net_return_pct / window_days.to_f) : 0.0

    sigma = vol_stats[:sigma_15m_return_pct].to_f
    step_to_sigma_ratio = sigma > 0.0 ? (grid_step_pct / sigma) : nil

    {
      number_of_grids:                          g,
      grid_step_pct:                            grid_step_pct,
      number_of_matching_pairs:                 matching_pairs,
      theoretical_net_return_per_cycle_pct:     theoretical_net_return_per_cycle_pct,
      realized_avg_net_return_per_cycle_pct:    realized_avg_net_return_per_cycle_pct,
      total_net_return_pct:                     total_net_return_pct,
      theoretical_net_return_per_day_pct:       theoretical_net_return_per_day_pct,
      step_to_sigma_ratio:                      step_to_sigma_ratio,
      sigma_15m_return_pct:                     sigma,
      median_abs_15m_return_pct:                vol_stats[:median_abs_15m_return_pct]
    }
  end
end
